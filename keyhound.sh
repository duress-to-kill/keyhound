#!/bin/bash
# Authored by Andrew Wood, 10/14/15
# mancat on irc.cat.pdx.edu, and at TheCAT, Portland State University
# www.github.com/mongolsamurai

# This is where your SSH server looks for authorized pubkeys for remote logins to your account
AUTHORIZED_KEYS_FILE=~/.ssh/authorized_keys

# This is a folder where keyhound will look for your pubkey collection
KEYDIR="`dirname $0`/pubkeys/"

#This is the lowest security ring you intend to use. Higher numbers are lower security.
LOWRING=3

KEYS_LEVEL[0]="amanita
  galerina"
KEYS_LEVEL[1]="${KEYS_LEVEL[0]}
  chanterelle
  morel
  oyster"
KEYS_LEVEL[2]="${KEYS_LEVEL[1]}
  hedgehog
  bolete
  chicken-of-the-woods"
KEYS_LEVEL[3]="${KEYS_LEVEL[2]}
  woodear
  toadstool"
#KEYS_LEVEL[4]="${KEYS_LEVEL[3]} "

helptext() {
  cat <<- ENDOFHELP
	Usage:
	$0 <-p|-P|-i> <0-${LOWRING}> [-l] [-A]
	$0 -c
	$0 -h
	-p <0-${LOWRING}>  - Print the list of hostnames associated with the keys in the specified security ring
	-P <0-${LOWRING}>  - Print the list of keys in the specified security ring
	-i <0-${LOWRING}>  - Install the keys associated with the specified security ring (overwrites existing keys)
	-d <dir>  - Use <dir>, instead of $KEYDIR, as the pubkey directory
	-f <file> - Use <file>, instead of $AUTHORIZED_KEYS_FILE, as your SSH authorized keys file
	-l        - Installs the key associated with localhost (this allows loopback ssh connections)
	-A        - Append to existing authorized_keys file, instead of overwriting (only valid with -p or -i)
	-c        - Check existing keys file against pubkey directory and report any unrecognized keys
	-h        - Prints this help text
	ENDOFHELP
  exit
}

key_comment_warning() {
  echo "WARNING! \"$1\" does not appear in the key $2. Check its contents to be sure it is correct."
}

check_keys() {
IFS='
'
for KEY in `cat $2`; do
  grep -q "$KEY" ${1}* || cat <<- ENDOFWARNING
	WARNING! The following public key was found in ${2}, but was not present in any pubkey file in ${1}!
	$KEY
	ENDOFWARNING
done

exit
}

while getopts hlAcf:d:i:p:P: FLAG; do
  ARGS=true
  case $FLAG in
    p | P | i)
      [ -n "$RING" ] && helptext
      [ -n "$OP_KEYCHECK" ] && helptext
      [ -z "${KEYS_LEVEL[${OPTARG}]}" ] &&\
        echo "Syntax error: \"$OPTARG\" is not a valid security ring. Try 0-{LOWRING}." && helptext
      OP_MODE=$FLAG
      RING=$OPTARG
      ;;
    d)
      # Use simple sed to ensure dirname ends in /
      [ -d "$OPTARG" ] || { echo "Error: $OPTARG does not exist, or is not a directory."; exit;}
      KEYDIR=`echo -n "$OPTARG" | sed -e 's_.*[^/]$_&/_'`
      ;;
    f)
      [ -f "$OPTARG" ] || { echo "Error: $OPTARG does not exist, or is not a file"; exit;}
      AUTHORIZED_KEYS_FILE="$OPTARG"
      ;;
    l)
      OP_LOCAL_KEY=true
      ;;
    A)
      OP_APPEND=true
      ;;
    c)
      [ -n "$RING" ] && helptext
      OP_KEYCHECK=true
      ;;
    h)
      helptext
      ;;
  esac
done

# If no arguments were given, print help test and exit
[ -z "$ARGS" ] && helptext

# If a key check was requested, run the function with any specified keydir and authorized key file, andexit.
[ -n "$OP_KEYCHECK" ] && check_keys "$KEYDIR" "$AUTHORIZED_KEYS_FILE"

if [ "$OP_MODE" == "p" ]; then
  for HOST in ${KEYS_LEVEL[$RING]}; do
    [ "$HOST" == "`hostname`" ] && [ -z "$OP_LOCAL_KEY" ] && continue
    echo $HOST
  done
  exit
fi

TEMPFILE=`mktemp -p ~/.ssh/ authorized_keys-temp.XXXXX`
chmod 600 $TEMPFILE
[ -n "$OP_APPEND" ] && cat $AUTHORIZED_KEYS_FILE > $TEMPFILE

for HOST in ${KEYS_LEVEL[$RING]}; do
  # If OP_LOCAL_KEY isn't set, and we're processing our own key, skip it.
  [ "$HOST" == "`hostname`" ] && [ -z "$OP_LOCAL_KEY" ] && continue
  KEYFILE="${KEYDIR}id_rsa.pub.${HOST}"
  # If we're missing one or more keys, print a warning and continue.
  [ -f "$KEYFILE" ] || { echo "Warning: Unable to find key ${KEYFILE}."; continue;}
  # Safety check to make sure the key we asked for is the one we found
  grep -q "$HOST" "$KEYFILE" || { key_comment_warning "$HOST" "$KEYFILE"; continue;}
  # Don't add the key if it's already in the file. Mostly for append mode.
  grep -q "`cat $KEYFILE`" $TEMPFILE || cat $KEYFILE >> $TEMPFILE
  #cat $KEYFILE
done

echo
if [ "$OP_MODE" == "P" ]; then
  cat $TEMPFILE
else
  if [ -f $AUTHORIZED_KEYS_FILE ]; then
    diff $TEMPFILE $AUTHORIZED_KEYS_FILE
    echo
    read -p "This is the diff between the keys to be installed, and those currently in place. Continue? " RESPONSE
  else
    cat $TEMPFILE
    echo
    read -p "These are the keys to be installed. (No existing keys found.) Continue? " RESPONSE
  fi
  echo "$RESPONSE" | egrep -q '^[Yy].*' &&\
    cat $TEMPFILE > $AUTHORIZED_KEYS_FILE
fi

rm $TEMPFILE

exit
