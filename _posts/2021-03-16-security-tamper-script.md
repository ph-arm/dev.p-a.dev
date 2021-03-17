---
title: "Security : SQLmap Tamper scripting"
layout: post
excerpt: "SQLMap tamper script reminder"
tags:
  - Code
  - SQL
  - CTF
  - Security
---

Forgot way too often how to tamper with sqlmap. The goal here is to simply pass a second parameter h that is a hash to verify the payload is indeed sent by a friendly agent knowing the key, or knowing the hash corresponding to the page.

{% gist 13e04a648720801cea71dd8f45276b3d proper_tamper.py  %}
