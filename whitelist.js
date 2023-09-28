#!/usr/bin/env node
const allowedEvents = JSON.parse(process.env.ALLOWED_EVENTS || "[]");
const whiteList = new Set(allowedEvents)
const rl = require('readline').createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on('line', (line) => {
    let req = JSON.parse(line);

    if (req.type !== 'new') {
        console.error("unexpected request type");
        return;
    }

    let res = { id: req.event.id, kind: req.event.kind };

    if (whiteList.has(req.event.kind)) {
        res.action = 'accept';
    } else {
        res.action = 'reject';
        res.msg = 'blocked: not on white-list';
    }

    console.log(JSON.stringify(res));
});