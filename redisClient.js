const redis = require('redis');

const REDIS_HOST = process.env.REDIS_HOST
const REDIS_PORT = Number(process.env.REDIS_PORT)

const REDIS_CONFIG = {
    HOST: REDIS_HOST,
    PORT: REDIS_PORT
};

let redisClient;


(async () => {
    if (!redisClient) {
        redisClient = redis.createClient({ socket: { host: REDIS_CONFIG.HOST, port: REDIS_CONFIG.PORT } });
    }
    await redisClient.connect();
})();

module.exports = { redisClient };