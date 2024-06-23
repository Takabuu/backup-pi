#!/bin/bash

# checks if script is started as root
if [ $(whoami) != 'root' ]; then
        echo 'Start Script as root' >&2
        exit 1
fi

dateiname=$HOSTNAME-`date '+%F'`.img
reboot=false
boot_device=$(findmnt -n / | awk '{ print $2 }' | sed 's/2$//')

while getopts "rhn:t:" OPTION; do
        case $OPTION in

                n)
                        dateiname=$OPTARG
                        ;;

                h)
                        echo "Usage:"
                        echo ""
                        echo "   -n filename	        define custom Filename"
                        echo "   -r		        reboot after backup"
			echo "   -h     	        help (this output)"
                        echo "   -t mountpoint          Mountpoint of Target"
                        exit 0
                        ;;
		t)
                        target=$OPTARG
                        ;;
                r)
			reboot=true
			;;
		\?)
			exit 1
			;;
        esac
done

#checks if variable target was set (target is mandatory)
if [ -z "$target" ]; then
        echo 'Missing -t' >&2
        exit 1
fi

# gets available backup space
available=$(df -B1 $target | awk ' END { print $4 }')

# get how big the bootable usb stick is
all_boot=$(lsblk -b $boot_device | awk ' NR==2 { print $4 }')

# gets used space of backup media
used=$(df -B1 $target | awk ' END { print $3 }')

# gets how much space the backup media has
all=$((available + used))

# gets how much space is available after next backup on backup disk
difference=$((available - all_boot))

# gets 2% of backup disk
percentage=$(($all/50))

# info
echo "#####################################"
echo "Remaining space gets checked."
echo Threshold: $percentage
echo After Backup: $difference

# if free space after backup is less than 5% this triggers
while [ $difference -lt $percentage ]
do
        # recalculate stuff
        available=$(df -B1 $target | awk ' END { print $4 }')
        difference=$((available - all_boot))

	# oldest file is established
        oldest_file=$(ls -p $target | grep -v / | grep $HOSTNAME | head -n 1)
        
	# oldest file gets removed
	rm "$target/$oldest_file"
        echo "After this Backup the available space will be under 2%."
        echo "File $target/$oldest_file was deleted."
done

echo "Space OK"

# disk gets backed up
echo "#####################################"
echo "Backup gets created"
dd bs=4M if=$boot_device of=$target/$dateiname
cd $target
# image gets shrunk
echo "#####################################"
echo "Backup gets shrunk"
# https://github.com/borgesnotes/pishrink-docker
docker run --privileged=true --rm --volume $(pwd):/workdir borgesnotes/pishrink pishrink -v $dateiname

# wenn reboot auf true gesetzt wurde wird nach 5 sekunden neugestartet
if [ "$reboot" == true ] ; then
	echo "#####################################"
	echo "Rebooting..."
	sleep 5
	shutdown -r 1
fi
