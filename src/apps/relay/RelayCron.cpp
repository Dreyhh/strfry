#include <hoytech/timer.h>

#include "RelayServer.h"


void RelayServer::runCron() {
    hoytech::timer cron;

    cron.setupCb = []{ setThreadName("cron"); };


    // Delete ephemeral events
    // FIXME: This is for backwards compat during upgrades, and can be removed eventually since
    // the newer style of finding ephemeral events relies on expiration=1

    cron.repeat(10 * 1'000'000UL, [&]{
        std::vector<uint64_t> expiredLevIds;

        {
            auto txn = env.txn_ro();

            auto mostRecent = getMostRecentLevId(txn);
            uint64_t cutoff = hoytech::curr_time_s() - cfg().events__ephemeralEventsLifetimeSeconds;
            uint64_t currKind = 20'000;

            while (currKind < 30'000) {
                uint64_t numRecs = 0;

                env.generic_foreachFull(txn, env.dbi_Event__kind, makeKey_Uint64Uint64(currKind, 0), lmdb::to_sv<uint64_t>(0), [&](auto k, auto v) {
                    numRecs++;
                    ParsedKey_Uint64Uint64 parsedKey(k);
                    currKind = parsedKey.n1;

                    if (currKind >= 30'000) return false;

                    if (parsedKey.n2 > cutoff) {
                        currKind++;
                        return false;
                    }

                    uint64_t levId = lmdb::from_sv<uint64_t>(v);

                    if (levId != mostRecent) { // prevent levId re-use
                        expiredLevIds.emplace_back(levId);
                    }

                    return true;
                });

                if (numRecs == 0) break;
            }
        }

        if (expiredLevIds.size() > 0) {
            auto txn = env.txn_rw();

            uint64_t numDeleted = 0;

            for (auto levId : expiredLevIds) {
                if (deleteEvent(txn, levId)) numDeleted++;
            }

            txn.commit();

            if (numDeleted) LI << "Deleted " << numDeleted << " ephemeral events";
        }
    });

    cron.run();

    while (1) std::this_thread::sleep_for(std::chrono::seconds(1'000'000));
}
