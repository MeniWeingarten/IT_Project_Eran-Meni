#!/bin/bash
# Collects one raw sample: Steam front page, prices, player counts, Discord counts
APPIDS="4115450,1091500,252490,413150,4530370"
INVITES="phantombladezero cyberpunkgame rust stardewvalley footballmanager"

DIR=raw/$(date +%Y-%m-%d)
FILE=$DIR/$(date +%H%M).json
mkdir -p $DIR

{
  echo '{"featured":'
  wget -qO- "https://store.steampowered.com/api/featuredcategories?cc=il"
  echo ',"prices":'
  wget -qO- "https://store.steampowered.com/api/appdetails?appids=$APPIDS&cc=il&filters=price_overview"
  echo ',"players":{'
  first=1
  for id in $(echo $APPIDS | tr "," " "); do
    [ $first = 1 ] || echo ','
    first=0
    echo "\"$id\":"
    wget -qO- "https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid=$id"
  done
  echo '},"discord":{'
  first=1
  for code in $INVITES; do
    [ $first = 1 ] || echo ','
    first=0
    echo "\"$code\":"
    wget -qO- "https://discord.com/api/v10/invites/$code?with_counts=true"
  done
  echo '}}'
} > $FILE

echo "Saved $FILE"
