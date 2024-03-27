#!/usr/bin/env node

const readline = require('readline');
const { redisClient } = require('./redisClient');

const defaultValues = {
  ALLOWED_EVENTS: "[9288,9289,9290,9291,9292,9294,9295,32121,32122,32123,32124,0,3,4,5,10002]",
  WHITELIST_PUBKEYS: "[]",
  RATE_LIMIT: 15,
  RATE_LIMIT_EXPIRY: 60,
  HIT_LIMIT: 3,
  HIT_EXPIRY: 900,
  LIMIT_PER_KIND: '{"9288":50}',
  EXPIRY_PER_KIND: '{"9288":300}',
  HIT_LIMIT_PER_KIND: '{"9288":3}',
  HIT_EXPIRY_PER_KIND: '{"9288":1800}'
}

const podName = process.env.POD_NAME;

const parseEnv = (key) => {
  switch (key) {
    case 'ALLOWED_EVENTS':
    case 'WHITELIST_PUBKEYS':
      return new Set(JSON.parse(process.env[key] || defaultValues[key]));
    case 'LIMIT_PER_KIND':
    case 'EXPIRY_PER_KIND':
    case 'HIT_LIMIT_PER_KIND':
    case 'HIT_EXPIRY_PER_KIND':
      return JSON.parse(process.env[key] || defaultValues[key]);
    default:
      return Number(process.env[key] || defaultValues[key]);
  }
};

const allowedEventsSet = parseEnv('ALLOWED_EVENTS')
const whitelistPubkeysSet = parseEnv('WHITELIST_PUBKEYS');

const rateLimitDefault = parseEnv('RATE_LIMIT');
const expiryDefault = parseEnv('RATE_LIMIT_EXPIRY');
const hitLimitDefault = parseEnv('HIT_LIMIT');
const hitExpiryDefault = parseEnv('HIT_EXPIRY');

const limitsPerKind = parseEnv('LIMIT_PER_KIND');
const expiryPerKind = parseEnv('EXPIRY_PER_KIND');
const hitLimitPerKind = parseEnv('HIT_LIMIT_PER_KIND');
const hitExpiryPerKind = parseEnv('HIT_EXPIRY_PER_KIND');

const isRateLimited = async (ip, kind) => {

  const key = limitsPerKind[kind] ? `rate_limit:${podName}:${ip}:${kind}` : `rate_limit:${podName}:${ip}`;
  const limit = Number(limitsPerKind[kind] || rateLimitDefault);
  const expiry = Number(expiryPerKind[kind] || expiryDefault);

  const hitExpiry = Number(hitExpiryPerKind[kind] || hitExpiryDefault);
  const hitLimit = Number(hitLimitPerKind[kind] || hitLimitDefault);
  const hitKey = hitLimitPerKind[kind] ? `hit_limit:${podName}:${ip}:${kind}` : `hit_limit:${podName}:${ip}`;

  const requests = Number(await redisClient.incr(key));
  const hits = Number(await redisClient.get(hitKey) || 0);

  if (requests === 1) {
    await redisClient.expire(key, expiry);
  }

  if (requests === limit && hits < hitLimit) {
    await redisClient.incr(hitKey);
  }

  if (hits === hitLimit) {
    await redisClient.expire(hitKey, hitExpiry);
    await redisClient.incr(hitKey);
    return true;
  }

  if (hits > hitLimit) return true;

  if (requests > limit) return true;

  return false;
}


const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on('line', async (line) => {
  try {
    const req = JSON.parse(line);
    await handleRequest(req);
  } catch (err) {
    console.error(`Error parsing line: ${err}`);
  }
});

const handleRequest = async (req) => {

  if (req.type !== 'new') {
    console.error("unexpected request type");
    return;
  }

  const { id, kind, pubkey } = req.event;
  const ip = req.sourceInfo
  const type = req.sourceType
  const rateLimited = type === 'Sync' ? false : await isRateLimited(ip, kind);
  const res = { id, kind };

  if (whitelistPubkeysSet.has(pubkey)) {
    res.action = 'accept';
  } else if (rateLimited) {
    res.action = 'reject';
    res.msg = 'blocked: rate limit exceeded';
  } else if (allowedEventsSet.has(kind)) {
    res.action = 'accept';
  } else {
    res.action = 'reject';
    res.msg = 'blocked: not on white-list';
  }

  console.log(JSON.stringify(res));
};
