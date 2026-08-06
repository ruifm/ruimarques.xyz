---
title: '{{ title (replace (replaceRE "^[0-9]{4}-[0-9]{2}-[0-9]{2}-" "" .File.ContentBaseName) "-" " ") }}'
description: ''
draft: true
---
