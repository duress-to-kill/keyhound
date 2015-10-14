# Keyhound
A script for managing SSH keyed logins between several (or many) hosts.

## Introduction
I operate a file server, two general-use work computers, a VPS, and a raspberry pi that pulls duty as a micro-server. I also have several work machines that I use heavily but don't own.
Needless to say, I have a lot of SSH keys to keep track of. I started keeping a copy of all of my pubkeys in a git repository that I host in my own private gitolite instance. This is convenient, I highly recommend it if your computing environment is complicated and highly interconnected like mine.
If you do, it may occur to you that it would be even better if you had a portable little script in that repo that could handle managing your SSH authorized_keys file for you, to make keeping track of what's installed where a little easier.
As it turns out, in this eventuality I've saved you the effort of actually writing said script. keyhound will happily do it for you.

## Setup
Keyhound is pretty simple. It has just a few expectations.
Mostly, it assumes that you have a directory where you collect all your SSH public keys, and you use something (like git) to sync a local copy of this directory to each host where you want to use keyhound. It also assumes your pubkeys follow the general naming scheme of "id_rsa.pub.hostname", where "hostname" is the name of the host where that key was generated.
It also assumes you have several general classes of security, which keyhound calls "rings" because I though it sounded cool. Each of your SSH platforms will be assigned into a ring, as will each of your keys. When you try to SSH to an account that's managed by keyhound, using a key that keyhound recognizes, this will be allowed if the key you're using belongs to an equal or lower (i.e. "inner", more secure) ring than the account does. I.e., a ring 0 key will get you into any keyhound-managed account. A ring 3 account can be accessed by any ring 0, 1, 2, or 3 key.
