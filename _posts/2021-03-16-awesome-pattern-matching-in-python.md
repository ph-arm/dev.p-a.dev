---
title: "Clean and simple pattern matching in python"
layout: post
excerpt: "clean pattern matching"
tags:
  - Code
---

Found this gem on stackoverflow. The design is really smooth, especially in a task that always feel like a burden, pattern regex matching.
what really shine is the cleaningness and the readability of the config, even if we have to correct the regex for the last element if there is no extra char after.

```python
#for nginx defualt log :
log_line='''10.10.14.5 - - [09/Mar/2021:17:27:33 +0200] "GET /ca_st/info.php HTTP/1.1" 404 153 "-" "Mozilla/5.0 (X11; Linux x86_64; rv:69.0) Gecko/20100101 Firefox/69.0"'''

config = '$remote_addr - $user [$timestamp] "$request" $response_code $response_size "$referer" "$user_agent"'
regex = ''.join(
    '(?P<' + g + '>.*?)' if g else re.escape(c)
    for g, c in re.findall(r'\$(\w+)|(.)', self.config))
# fix the regex if the last element has nothng afer:
if regex[-2] == '?':
    regex = regex[:-2]+')'

reg_ = re.compile(regex)
match = reg_.search(log_line.strip())
return match.groupdict()

```