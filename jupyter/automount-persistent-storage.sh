#!/usr/bin/env bash

# To schedule it:
# * * * * * /root/automount-persistent-storage.sh  >> /var/log/script_output.log 2>&1

FILE=/AUTO_MOUNT_EXECUTED

if [ ! -f $FILE ]; then
   echo "Automounted file does not exists"

      IS_SDB_MOUNTED=`/sbin/blkid -s UUID -o value /dev/sdb`
      touch $FILE

      if [ -n "$IS_SDB_MOUNTED" ]; then
         echo "Sdb is available with UUID $IS_SDB_MOUNTED. Time to mount.."
         mount -o discard,defaults /dev/sdb /mnt/testdisk/
      else
         rm $FILE
      fi
fi
