#!/bin/bash
# Authored by Andrew Wood, 10/14/15
# mancat on irc.cat.pdx.edu, and at TheCAT, Portland State University
# www.github.com/mongolsamurai

#
# Configurables begin here.
#

# This is where your SSH server looks for authorized pubkeys for remote logins to your account
AUTHORIZED_KEYS_FILE=~/.ssh/authorized_keys

# This is a folder where keyhound will look for your pubkey collection
KEYDIR="`dirname $0`/pubkeys/"

# This is the lowest security ring you intend to use. Higher numbers are lower security.
LOWRING=2

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
#KEYS_LEVEL[3]="${KEYS_LEVEL[2]}
#  woodear
#  toadstool"
#KEYS_LEVEL[4]="${KEYS_LEVEL[3]} "


#
# Helper functions begin here.
# Code below here is not intended for configuration.
#

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

#
# Fixmes without a specific associated line go here.
#

# FIXME: Add ssh key fingerprint checking to verify that keys are valid.
# FIXME: Change sanity check for flag processing on p|P|i to use integer math on
#   $LOWRING instead of (in addition to?) string length checking on array contents.
# FIXME: Add signal handler to clean up tempfile on ^C and ^\.
# FIXME: Strip comments out of any lines copied from existing file during append operation
# FIXME: Test all changes since beta version.

#
# Argument parsing begins here.
#

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
    *)
      helptext
      ;;
  esac
done

# If no arguments were given, print help test and exit
[ -z "$ARGS" ] && helptext

#
# Parameter sanity checking begins here.
#

# General sanity check for the desitnation directory for AUTHORIZED_KEYS_FILE
AUTHORIZED_KEYS_DIR=`dirname "$AUTHORIZED_KEYS_FILE"`
if [ ! -d "$AUTHORIZED_KEYS_DIR" ] || [ ! -w "$AUTHORIZED_KEYS_DIR" ]; then
  cat <<- ENDOFNOTICE
	The specified directory ($AUTHORIZED_KEYS_DIR) for your authorized_keys file doesn't exist, or doesn'thave the correct permissions.
	ENDOFNOTICE
  read -p "Fix this? [Y/n]: " RESPONSE
  echo "$RESPONSE" | egrep -q '^[Yy]' || { echo "Aborting..."; exit;}
  mkdir -p "$AUTHORIZED_KEYS_DIR" 2> /dev/null
  chmod 600 "$AUTHORIZED_KEYS_DIR" 2> /dev/null
fi

#
# Task execution blocks begin here.
#

# If a key check was requested, run the function with any specified keydir and authorized key file, andexit.
[ -n "$OP_KEYCHECK" ] && check_keys "$KEYDIR" "$AUTHORIZED_KEYS_FILE"

if [ "$OP_MODE" == "p" ]; then
  for HOST in ${KEYS_LEVEL[$RING]}; do
    [ "$HOST" == "`hostname`" ] && [ -z "$OP_LOCAL_KEY" ] && continue
    echo $HOST
  done
  exit
fi

TEMPFILE=`mktemp -p "$AUTHORIZED_KEYS_DIR" authorized_keys-temp.XXXXXX`
chmod 600 $TEMPFILE
echo "# File created by `basename $0`, `date` at security ring $RING" > $TEMPFILE
[ -n "$OP_APPEND" ] && cat $AUTHORIZED_KEYS_FILE >> $TEMPFILE

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
