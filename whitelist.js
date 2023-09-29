#!/usr/bin/env node

const readline = require('readline');

// Function to parse environment variables
const parseEnvVariable = (key, defaultValue = "[]") => {
  return new Set(JSON.parse(process.env[key] || defaultValue));
};

const allowedEventsSet = parseEnvVariable('ALLOWED_EVENTS');
const whitelistPubkeysSet = parseEnvVariable('WHITELIST_PUBKEYS');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on('line', (line) => {
  try {
    const req = JSON.parse(line);
    handleRequest(req);
  } catch (err) {
    console.error(`Error parsing line: ${err}`);
  }
});

const handleRequest = (req) => {
  if (req.type !== 'new') {
    console.error("unexpected request type");
    return;
  }

  const { id, kind, pubkey } = req.event;
  const res = { id, kind };

  if (whitelistPubkeysSet.has(pubkey)) {
    res.action = 'accept';
  } else if (allowedEventsSet.has(kind)) {
    res.action = 'accept';
  } else {
    res.action = 'reject';
    res.msg = 'blocked: not on white-list';
  }

  console.log(JSON.stringify(res));
};
