#!/usr/bin/env bash
# Builds index.html (installable PWA) from src/app.html.
set -euo pipefail
cd "$(dirname "$0")"
src=src/app.html
head_part=$(sed '/<!--BODY-->/,$d' "$src")
body_part=$(sed '1,/<!--BODY-->/d' "$src")
{
cat <<'HEAD'
<!doctype html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="מטרות">
<meta name="theme-color" content="#f2f3f0" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#050706" media="(prefers-color-scheme: dark)">
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" type="image/svg+xml" href="icons/icon.svg">
<link rel="apple-touch-icon" href="icons/apple-touch-icon.png">
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}[hidden]{display:none!important}</style>
HEAD
echo "$head_part"
echo "</head>"
echo "<body>"
echo "$body_part"
echo "</body>"
echo "</html>"
} > index.html
echo "built index.html"
