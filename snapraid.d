Name{number}
	snapraid - SnapRAID Backup For Disk Arrays

Synopsis
	:snapraid [-c, --conf CONFIG]
	:	[-f, --filter PATTERN] [-d, --filter-disk NAME]
	:	[-m, --filter-missing] [-e, --filter-error]
	:	[-a, --audit-only] [-h, --pre-hash] [-i, --import DIR]
	:	[-p, --percentage PERC] [-o, --older-than DAYS]
	:	[-l, --log FILE]
	:	[-Z, --force-zero] [-E, --force-empty]
	:	[-U, --force-uuid] [-D, --force-device]
	:	[-N, --force-nocopy] [-F, --force-full]
	:	[-S, --start BLKSTART] [-B, --count BLKCOUNT]
	:	[-L, --error-limit NUMBER]
	:	[-v, --verbose] [-q, --quiet]
	:	status|smart|up|down|diff|sync|scrub|fix|check|list|dup
	:	|up|down|pool|devices|rehash

	:snapraid [-V, --version] [-H, --help] [-C, --gen-conf CONTENT]

Description
	SnapRAID is a backup program for disk arrays. It stores parity
	information of your data and it recovers from up to six disk
	failures.

	SnapRAID is mainly targeted for a home media center, with a lot of
	big files that rarely change.

	Beside the ability to recover from disk failures, other
	features of SnapRAID are:

	* All your data is hashed to ensure data integrity and to avoid
		silent corruption.
	* If the failed disks are too many to allow a recovery,
		you lose the data only on the failed disks.
		All the data in the other disks is safe.
	* If you accidentally delete some files in a disk, you can
		recover them.
	* You can start with already filled disks.
	* The disks can have different sizes.
	* You can add disks at any time.
	* It doesn't lock-in your data. You can stop using SnapRAID at any
		time without the need to reformat or move data.

	The official site of SnapRAID is:

		:http://snapraid.sourceforge.net

Limitations
	SnapRAID is in between a RAID and a Backup program trying to get the best
	benefits of them. Although it also has some limitations that you should
	consider before using it.

	The main one is that if a disk fails, and you haven't recently synced,
	you may be unable to do a complete recover.
	More specifically, you may be unable to recover up to the size of the
	amount of the changed or deleted files from the last sync operation.
	This happens even if the files changed or deleted are not in the
	failed disk. This is the reason because SnapRAID is better suited for
	data that rarely change.

	Instead the new added files don't prevent the recovering of the already
	existing files. You may only lose the just added files, if they are on
	the failed disk.

	Other limitations are:

	* You have different file-systems for each disk.
		Using a RAID you have only a big file-system.
	* It doesn't stripe data.
		With RAID you get a speed boost with striping.
	* It doesn't support real-time recovery.
		With RAID you do not have to stop working when a disk fails.
	* It's able to recover damages only from a limited number of disks.
		With a Backup you are able to recover from a complete
		failure of the whole disk array.
	* Only file, timestamps, symlinks and hardlinks are saved.
		Permissions, ownership and extended attributes are not saved.

Getting Started
	To use SnapRAID you need to first select one disk of your disk array
	to dedicate at the "parity" information. With one disk for parity you
	will be able to recover from a single disk failure, like RAID5.

	If you want to be able to recover from more disk failures, like RAID6,
	you must reserve additional disks for parity. Any additional parity
	disk allow to recover from one more disk failure.

	As parity disks, you have to pick the biggest disks in the array,
	as the parity information may grow in size as the biggest data
	disk in the array.

	These disks will be dedicated to store the "parity" files.
	You should not store your data in them.

	Then you have to define the "data" disks that you want to protect
	with SnapRAID. The protection is more effective if these disks
	contain data that rarely change. For this reason it's better to
	DO NOT include the Windows C:\ disk, or the Unix /home, /var and /tmp
	disks.

	The list of files is saved in the "content" files, usually
	stored in the data, parity or boot disks.
	These files contain the details of your backup, with all the
	checksums to verify its integrity.
	The "content" file is stored in multiple copies, and each one must
	be in a different disk, to ensure that in even in case of multiple
	disk failures at least one copy is available.

	For example, suppose that you are interested only at one parity level
	of protection, and that your disks are present in:

		:/mnt/diskp <- selected disk for parity
		:/mnt/disk1 <- first disk to protect
		:/mnt/disk2 <- second disk to protect
		:/mnt/disk3 <- third disk to protect

	you have to create the configuration file /etc/snapraid.conf with
	the following options:

		:parity /mnt/diskp/snapraid.parity
		:content /var/snapraid/snapraid.content
		:content /mnt/disk1/snapraid.content
		:content /mnt/disk2/snapraid.content
		:disk d1 /mnt/disk1/
		:disk d2 /mnt/disk2/
		:disk d3 /mnt/disk3/

	If you are in Windows, you should use drive letters and backslashes
	instead of slashes, and if you like, also file extensions.

		:parity E:\snapraid.parity
		:content C:\snapraid\snapraid.content
		:content F:\array\snapraid.content
		:content G:\array\snapraid.content
		:disk d1 F:\array\
		:disk d2 G:\array\
		:disk d3 H:\array\

	At this point you are ready to start the "sync" command to build the
	parity information.

		:snapraid sync

	This process may take some hours the first time, depending on the size
	of the data already present in the disks. If the disks are empty
	the process is immediate.

	You can stop it at any time pressing Ctrl+C, and at the next run it
	will start where interrupted.

	When this command completes, your data is SAFE.

	Now you can start using your array as you like, and periodically
	update the parity information running the "sync" command.

  Scrubbing
	To periodically check the data and parity for errors, you can
	run the "scrub" command.

		:snapraid scrub

	This command verifies the data in your array comparing it with
	the hash computed in the "sync" command.

	Every run of the command checks about 12% of the array, but not data newer
	than 10 days.
	You can use the -p, --percentage option to specify a different amount,
	and the -o, --older-than option to specify a different age in days.
	For example, to check 5% of the array older than 20 days use:

		:snapraid -p 5 -o 20 scrub

	If during the process, silent or input/output errors are found,
	the corresponding blocks are marked as bad in the "content" file,
	and listed in the "status" command.

		:snapraid status

	To fix them, you can use the "fix" command filtering for bad blocks with
	the -e, --filter-error options:

		:snapraid -e fix

	At the next "scrub" the errors will disappear from the "status" report
	if really fixed. To make it fast, you can use -p 0 to scrub only blocks
	marked as bad.

		:snapraid -p 0 scrub

	Take care that running "scrub" on a not synced array may result in
	errors caused by removed or modified files. These errors are reported
	in the "scrub" result, but related blocks are not marked as bad.

  Pooling
	To have all the files in your array shown in the same directory tree,
	you can enable "pooling", that consists in creating a virtual view of all
	the files in your array using symbolic links.

	You can configure the "pooling" directory in the configuration file with:

		:pool /pool

	or, if you are in Windows, with:

		:pool C:\pool

	and then run the "pool" command to create or update the virtual view.

		:snapraid pool

	If you are using a Unix platform and you want to share such directory
	in the network to either Windows or Unix machines, you should add
	to your /etc/samba/smb.conf the following options:

		:# In the global section of smb.conf
		:unix extensions = no

		:# In the share section of smb.conf
		:[pool]
		:comment = Pool
		:path = /pool
		:read only = yes
		:guest ok = yes
		:wide links = yes
		:follow symlinks = yes

	In Windows the same sharing operation is not so straightforward,
	because Windows shares the symbolic links as they are, and that
	requires the network clients to resolve them remotely.

	To make it working, besides sharing in the network the pool directory,
	you must also share all the disks independently, using as share points
	the disk names as defined in the config file. You must also specify in
	the "share" option of the configure file, the Windows UNC path that remote
	clients needs to use to access such shared disks.

	For example, operating from a server named "darkstar", you can use
	the options:

		:disk d1 F:\array\
		:disk d2 G:\array\
		:disk d3 H:\array\
		:pool C:\pool
		:share \\darkstar

	and share the following dirs in the network:

		:\\darkstar\pool -> C:\pool
		:\\darkstar\d1 -> F:\array
		:\\darkstar\d2 -> G:\array
		:\\darkstar\d3 -> H:\array

	to allow remote clients to access all the files at \\darkstar\\pool.

	You may also need to configure remote clients, to enable the access at
	remote symlinks with the command:

		:fsutil behavior set SymlinkEvaluation L2L:1 R2R:1 L2R:1 R2L:1

  Undeleting
	SnapRAID is more like a backup program than a RAID system, and it
	can be used to restore or undelete files to their previous state using
	the -f, --filter option :

		:snapraid fix -f FILE

	or for a directory:

		:snapraid fix -f DIR/

	You can also use it to recover only accidentally deleted files inside
	a directory using the -m, --filter-missing option, that restores
	only missing files, leaving untouched all the others.

		:snapraid fix -m -f DIR/

	Or to recover all the deleted files in all the drives with:

		:snapraid fix -m

  Recovering
	The worst happened, and you lost a disk!

	DO NOT PANIC! You will be able to recover it!

	The first thing you have to do is to avoid further changes at you disk array.
	Disable any remote connection to it, any scheduled process, including any
	scheduled SnapRAID nightly sync or scrub.

	Then proceed with the following steps.

    STEP 1 -> Reconfigure
	You need some space to recover, even better if you already have an additional
	disk, but in case, also an external USB or remote disk is enough.
    
	Change the SnapRAID configuration file to make the "disk" option
	of the failed disk to point to the place where you have enough empty
	space to recover the files.

	For example, if you have that disk "d1" failed, you can change from:

		:disk d1 /mnt/disk1/

	to:

		:disk d1 /mnt/new_spare_disk/

    STEP 2 -> Fix
	Run the fix command, storing the log in an external file with:

		:snapraid -d NAME -l fix.log fix

	Where NAME is the name of the disk, like "d1" as in our previous example.

	This command will take a long time.

	Take care that you need also few gigabytes free to store the fix.log file.
	Run it from a disk with some free space.

	Now you have recovered all the recoverable. If some file is partially or totally
	unrecoverable, it will be renamed adding the ".unrecoverable" extension.

	You can get a detailed list of all the unrecoverable blocks in the fix.log file
	checking all the lines starting with "unrecoverable:"

	If you are not satisfied of the recovering, you can retry it as many
	time you wish.

	For example, if you have removed files from the array after the last
	"sync", this may result in some other files not recovered.
	In this case, you can retry the "fix" using the -i, --import option,
	specifing where these files are now, to include them again in the
	recovering process.

	If you are satisfied of the recovering, you can now proceed further,
	but take care that after syncing you cannot retry the "fix" command
	anymore!

    STEP 3 -> Check
	As paranoid check, you can now run a "check" command to ensure that
	everything is OK on the recovered disk.

		:snapraid -d NAME -a check

	Where NAME is the name of the disk, like "d1" as in our previous example.

	The options -d and -a tell SnapRAID to check only the specified disk,
	and ignore all the parity data.

	This command will take a long time, but if you are not paranoid,
	you can skip it.

    STEP 4 -> Sync
	Run the "sync" command to resynchronize the array with the new disk.

		:snapraid sync

	If everything is recovered, this command is immediate.

Commands
	SnapRAID provides a few simple commands that allow to:

	* Prints the status of the array -> "status"
	* Controls the disks -> "smart", "up", "down"
	* Makes a backup/snapshot -> "sync"
	* Periodically checks data -> "scrub"
	* Restore the last backup/snapshot -> "fix".

	Take care that the commands have to be written in lower case.

  status
	Prints a summary of the state of the disk array.

	It includes information about the parity fragmentation, how old
	are the blocks without checking, and all the recorded silent
	errors encountered while scrubbing.

	Note that the information presented refers at the latest time you
	run "sync". Later modifications are not taken into account.

	Nothing is modified.

  smart
	Prints a SMART report of all the disks of the array.

	It includes an estimation of the probability of failure in the next
	year allowing to plan maintenance replacements of the disks that show
	suspicious attributes.

	This probability estimation obtained correlating the SMART attributes
	of the disks, with the Backblaze data available at:

		:https://www.backblaze.com/hard-drive-test-data.html

	If SMART reports that a disk is failing, "FAIL" or "PREFAIL" is printed
	for that disk, and SnapRAID returns with an error.
	In this case an immediate replacement of the disk is highly recommended.

	Other possible strings are:
		logfail - In the past some attributes were lower than
			the threshold.
		logerr - The device error log contains errors.
		selferr - The device self-test log contains errors.

	If the -v, --verbose option is specified a deeper statistical analysis
	is provided. This analysis can help you to decide if you need more
	or less parity.

	This command uses the "smartctl" tool, and it's equivalent to run
	"smartctl -a" on all the devices.

	If your devices are not autodetected correctly, you can configure
	a custom command using the "smartctl" option in the configuration
	file.

	Nothing is modified.

  up
	Spins up all the disks of the array.

	Nothing is modified.

  down
	Spins down all the disks of the array.

	This command uses the "smartctl" tool, and it's equivalent to run
	"smartctl -s standby,now" on all the devices.

	Nothing is modified.

  diff
	Lists all the files modified from the last "sync" that need to have
	their parity data recomputed.

	This command doesn't check the file data, but only the file timestamp
	size and inode.

	If a "sync" is not required, the return error code is 0. Otherwise,
	it's 1.

	Nothing is modified.

  sync
	Updates the parity information. All the modified files
	in the disk array are read, and the corresponding parity
	data is updated.

	You can stop this process at any time pressing Ctrl+C,
	without losing the work already done.
	At the next run the "sync" process will start where
	interrupted.

	If during the process, silent or input/output errors are found,
	the corresponding blocks are marked as bad.

	Files are identified by path and/or inode and checked by
	size and timestamp.
	If the file size or timestamp are different, the parity data
	is recomputed for the whole file.
	If the file is moved or renamed in the same disk, keeping the
	same inode, the parity is no recomputed.
	If the file is moved to another disk, the parity is recomputed,
	but the previously compute hash information is kept.

	The "content" and "parity" files are modified if necessary.
	The files in the array are NOT modified.

  scrub
	Scrubs the array, checking for silent or input/output errors in data
	and parity disks.

	For each command invocation, the 12% of the array is checked, but
	nothing that it's more recent than 10 days.
	This means that scrubbing once a week, every bit of data is checked
	at least one time every two months.

	You can use the -p, --percentage option to specify a different amount,
	and the -o, --older-than option to specify a different age in days.
	You can have a full scrub with "-p 100 -o 0".

	The oldest blocks are scrubbed first ensuring an optimal check.

	For any silent or input/output error found the corresponding blocks
	are marked as bad in the "content" file.
	These bad blocks are listed in "status", and can be fixed with "fix -e".
	After the fix, at the next scrub they will be rechecked, and if found
	corrected, the bad mark will be removed.

	It's recommended to run "scrub" on a synced array, to avoid to have
	reported error caused by unsynced data. These errors are recognized
	as not being silent errors, and the blocks are not marked as bad,
	but such errors are reported in the output of the command.

	Files are identified only by path, and not by inode.

	The "content" file is modified to update the time of the last check
	of each block, and to mark bad blocks.
	The "parity" files are NOT modified.
	The files in the array are NOT modified.

  fix
	Fix all the files and the parity data.

	All the files and the parity data are compared with the snapshot
	state saved in the last "sync".
	If a difference is found, it's reverted to the stored snapshot.

	Note that "fix" doesn't differentiate between errors and intentional
	modifications. It inconditionally reverts the file state at the last "sync".

	If no other option is specified the full array is processed.
	Use the filter options to select a subset of files or disks to operate on.

	To only fix the blocks marked bad during "sync" and "scrub",
	use the -e, --filter-error option.
	As difference from other filter options, with this one fixes are
	applied only to files that are not modified from the the latest "sync".

	All the files that cannot be fixed are renamed adding
	the ".unrecoverable" extension.

	Files are identified only by path, and not by inode.

	The "content" file is NOT modified.
	The "parity" files are modified if necessary.
	The files in the array are modified if necessary.

  check
	Verify all the files and the parity data.

	It works like "fix", but it only simulates a recovery and no change
	is written in the array.

	This command is mostly intended for manual verifications,
	like after a recovery process or in other special conditions.
	For periodic and scheduled checks uses "scrub".

	If you use the -a, --audit-only option, only the file
	data is checked, and the parity data is ignored for a
	faster run.

	Files are identified only by path, and not by inode.

	Nothing is modified.

  list
	Lists all the files contained in the array at the time of the
	last "sync".

	Nothing is modified.

  dup
	Lists all the duplicate files. Two files are assumed equal if their
	hashes are matching. The file data is not read, but only the
	precomputed hashes are used.

	Nothing is modified.

  up
	Spins up all the disks of the array.

	Nothing is modified.

  down
	Spins down all the disks of the array.

	Nothing is modified.

  pool
	Creates or updates in the "pooling" directory a virtual view of all
	the files of your disk array.

	The files are not really copied here, but just linked using
	symbolic links.

	When updating, all the present symbolic links and empty
	subdirectories are deleted and replaced with the new
	view of the array. Any other regular file is left in place.

	Nothing is modified outside the pool directory.

  devices
	Prints the low level devices used by the array.

	This command prints the devices associations in place in the array,
	and it's mainly intended as a script interface.

	The first two columns are the low level device id and path.
	The next two columns are the high level device id and path.
	The latest column if the disk name in the array.

	In most cases you have one low level device for each disk in the
	array, but in some more complex configurations, you may have multple
	low level devices used by a single disk in the array.

	Nothing is modified.

  rehash
	Schedules a rehash of the whole array.

	This command changes the hash kind used, typically when upgrading
	from a 32 bits system to a 64 bits one, to switch from
	MurmurHash3 to the faster SpookyHash.

	If you are already using the optimal hash, this command
	does nothing and tells you that nothing has to be done.

	The rehash isn't done immediately, but it takes place
	progressively during "sync" and "scrub".

	You can get the rehash state using "status".

	During the rehash, SnapRAID maintains full functionality,
	with the only exception of "dup" not able to detect duplicated
	files using a different hash.

Options
	SnapRAID provides the following options:

	-c, --conf CONFIG
		Selects the configuration file. If not specified it's assumed
		the file "/etc/snapraid.conf" in Unix, and "snapraid.conf" in
		the current directory in Windows.

	-f, --filter PATTERN
		Filters the files to process in "check" and "fix".
		Only the files matching the entered pattern are processed.
		This option can be used many times.
		See the PATTERN section for more details in the
		pattern specifications.
		In Unix, ensure to quote globbing chars if used.
		This option can be used only with "check" and "fix".
		Note that it cannot be used with "sync" and "scrub", because they always
		process the whole array.

	-d, --filter-disk NAME
		Filters the files to process in "check" and "fix".
		Only the files present in the specified disk are processed.
		You must specify a disk name as named in the configuration
		file.
		In "check", you can make it faster, specifying also -a, --audit-only
		option, to avoid to access other disks to check parity data.
		If you combine more --filter, --filter-disk and --filter-missing options,
		only files matching all the set of filters are selected.
		This option can be used many times.
		This option can be used only with "check" and "fix".
		Note that it cannot be used with "sync" and "scrub", because they always
		process the whole array.

	-m, --filter-missing
		Filters the files to process in "check" and "fix".
		Only the files missing/deleted from the array are processed.
		When used with "fix", this is a kind of "undelete" command.
		If you combine more --filter, --filter-disk and --filter-missing options,
		only files matching all the set of filters are selected.
		This option can be used only with "check" and "fix".
		Note that it cannot be used with "sync" and "scrub", because they always
		process the whole array.

	-e, --filter-error
		Filters the blocks to process in "check" and "fix".
		It processes only the blocks marked with silent or input/output
		errors during "sync" and "scrub", and listed in "status".
		This option can be used only with "check" and "fix".

	-p, --percentage PERC
		Selects the part of the array to process in "scrub".
		PERC is a numeric value from 0 to 100, default is 12.
		When specifying 0, only the blocks marked as bad are scrubbed.
		This option can be used only with "scrub".

	-o, --older-than DAYS
		Selects the older the part of the array to process in "scrub".
		DAYS is the minimum age in days for a block to be scrubbed,
		default is 10.
		Blocks marked as bad are always scrubbed despite this option.
		This option can be used only with "scrub".

	-a, --audit-only
		In "check" verifies the hash of the files without
		doing any kind of check on the parity data.
		If you are interested in checking only the file data this
		option can speedup a lot the checking process.
		This option can be used only with "check".

	-h, --pre-hash
		In "sync" runs a preliminary hashing phase of all
		the new data to verify the data used in the parity computation.
		Usually in "sync" no preliminary hashing is done, and the new
		data is hashed just before the parity computation when it's read
		for the first time,
		Unfortunately, this process happens when the system is under
		heavy load, with all disks spinning and a busy CPU.
		This is an extreme condition for your machine, and if it has a
		latent hardware problem, it's possible to encounter silent errors
		what cannot be detected because the data is not yet hashed.
		To avoid this risk, you can enable the "pre-hash" mode and have
		all the data hashed two times to ensure its integrity.
		This option can be used only with "sync".

	-i, --import DIR
		Imports from the specified directory any file that you deleted
		from the array after the last "sync".
		If you still have such files, they could be used by "check"
		and "fix" to improve the recover process.
		The files are read also in subdirectories and they are
		identified regardless of their name.
		This option can be used only with "check" and "fix".

	-Z, --force-zero
		Forces the insecure operation of syncing a file with zero
		size that before was not.
		If SnapRAID detects a such condition, it stops proceeding
		unless you specify this option.
		This allows to easily detect when after a system crash,
		some accessed files were truncated.
		This is a possible condition in Linux with the ext3/ext4
		filesystems.
		This option can be used only with "sync".

	-E, --force-empty
		Forces the insecure operation of syncing a disk with all
		the original files missing.
		If SnapRAID detects that all the files originally present
		in the disk are missing or rewritten, it stops proceeding
		unless you specify this option.
		This allows to easily detect when a data file-system is not
		mounted.
		This option can be used only with "sync".

	-U, --force-uuid
		Forces the insecure operation of syncing, checking and fixing
		with disks that have changed their UUID.
		If SnapRAID detects that some disks have changed UUID,
		it stops proceeding unless you specify this option.
		This allows to detect when your disks are mounted in the
		wrong mount points.
		It's anyway allowed to have a single UUID change with
		single parity, and more with multiple parity, because it's
		the normal case of replacing disks after a recovery.
		This option can be used only with "sync", "check" or
		"fix".

	-D, --force-device
		Forces the insecure operation of fixing with disks on the same
		physical device.
		If SnapRAID detects that some disks have the same device ID,
		it stops proceeding, because it's not a supported configuration.
		But it could happen that you want to temporarily restore a lost
		disk in the free space left in an already used disk. and this
		option allows you to continue anyway.
		This option can be used only with "fix".

	-N, --force-nocopy
		In "sync", "check and "fix", disables the copy detection heuristic.
		Without this option SnapRAID assumes that files with same
		attributes, like name, size and timestamp are copies with the
		same data.
		This allows to identify copied or moved files from one disk
		to another, and to reuse the already computed hash information
		to detect silent errors or to recover missing files.
		This behavior, in some rare cases, may result in false positives,
		or in a slow process due the many hash verifications, and this
		option allows to resolve them.
		This option can be used only with "sync", "check" and "fix".

	-F, --force-full
		In "sync" forces a full rebuild of the parity.
		This option can be used when you reverted back to an old content
		file, but using a more recent parity data.
		Instead of recomputing the parity from scratch, this allows
		to reuse the hashes present in the content file to validate data,
		and to maintain data protection during the "sync" process using
		the old content file and the parity data you have.
		This option can be used only with "sync".

	-l, --log FILE
		Write a detailed log in the specified file.
		If this option is not specified, the warnings and not fatal
		errors are printed on the screen, likely resulting in too much
		output in case of many errors.
		If the path starts with '>>' the file is opened
		in append mode. Occurrences of '%D' and '%T' in the name are
		replaced with the date and time in the format YYYYMMDD and
		HHMMSS. Note that in Windows batch files, you'll have to double
		the '%' char, like result-%%D.log. And to use '>>' you'll have
		to enclose the name in ", like ">>result.log".
		To output the log to standard output or standard error,
		you can use respectively ">&1" and ">&2".

	-L, --error-limit
		Sets a new error limit before stopping execution.
		By default SnapRAID stops if it encouters more than 100
		Input/Output errors, meaning that likely a disk is going to
		die.
		This options affects "sync" and "scrub", that are allowed
		to continue after the first bunch of disk errors, to try
		to complete at most their operations.
		Instead, "check" and "fix" always stop at the first error.

	-S, --start BLKSTART
		Starts the processing from the specified
		block number. It could be useful to retry to check
		or fix some specific block, in case of a damaged disk.
		It's present mainly for advanced manual recovering.

	-B, --count BLKCOUNT
		Processes only the specified number of blocks.
		It's present mainly for advanced manual recovering.

	-C, --gen-conf CONTENT_FILE
		Generates a dummy configuration file from an existing
		content file.
		The configuration file is written in the standard output,
		and it doesn't overwrite an existing one.
		This configuration file also contains the information
		needed to reconstruct the disk mount points, in case you
		lose the entire system.

	-v, --verbose
		Prints more information on the screen.

	-q, --quiet
		Prints less information on the screen.
		If specified one time, removes the progress bar, if two
		times, the running operations, three times, the info
		messages, four times the status messages.
		Fatal errors are always printed.

	-H, --help
		Prints a short help screen.

	-V, --version
		Prints the program version.

Configuration
	SnapRAID requires a configuration file to know where your disk array
	is located, and where storing the parity information.

	This configuration file is located in /etc/snapraid.conf in Unix or
	in the execution directory in Windows.

	It should contain the following options (case sensitive):

  parity FILE
	Defines the file to use to store the parity information.
	The parity enables the protection from a single disk
	failure, like RAID5.
	
	It must be placed in a disk dedicated for this purpose with
	as much free space as the biggest disk in the array.
	Leaving the parity disk reserved for only this file ensures that
	it doesn't get fragmented, improving the performance.

	This option is mandatory and it can be used only one time.

  [2,3,4,5,6]-parity FILE
	Defines the files to use to store extra parity information.
	For each parity file specified, one additional level of protection
	is enabled:

	* 2-parity enables RAID6 double parity.
	* 3-parity enables triple parity
	* 4-parity enables quad parity
	* 5-parity enables penta (five) parity
	* 6-parity enables hexa (six) parity

	Each parity level requires also all the files of the previous levels.

	Each file must be placed in a disk dedicated for this purpose with
	as much free space as the biggest disk in the array.
	Leaving the parity disks reserved for only these files ensures that
	they doesn't get fragmented, improving the performance.

	These options are optional and they can be used only one time.

  z-parity FILE
	Defines an alternate file and format to store the triple parity.

	This option is an alternative at '3-parity' mainly intended for
	low-end CPUs like ARM or AMD Phenom, Athlon and Opteron that don't
	support the SSSE3 instructions set, and in such case it provides
	a better performance.

	This format is similar, but faster, at the one used by the ZFS RAIDZ3,
	but it doesn't work beyond triple parity.

	When using '3-parity' you will be warned if it's recommended to use
	the 'z-parity' format for a performance improvement.

	It's possible to convert from one format to another, adjusting
	the configuration file with the wanted z-parity or 3-parity file,
	and using 'fix' to recreate it.

  content FILE
	Defines the file to use to store the list and checksums of all the
	files present in your disk array.

	It can be placed in the disk used to store data, parity, or
	any other disk available.
	If you use a data disk, this file is automatically excluded
	from the "sync" process.

	This option is mandatory and it can be used more times to save
	more copies of the same files.

	You have to store at least one copy for each parity disk used
	plus one. Using some more doesn't hurt.

  disk NAME DIR
	Defines the name and the mount point of the disks of the array.
	NAME is used to identify the disk, and it must be unique.
	DIR is the mount point of the disk in the filesystem.

	You can change the mount point as you like, as long you
	keep the NAME fixed.

	You should use one option for each disk of the array.

  nohidden
	Excludes all the hidden files and directory.
	In Unix hidden files are the ones starting with ".".
	In Windows they are the ones with the hidden attribute.

  exclude/include PATTERN
	Defines the file or directory patterns to exclude and include
	in the sync process.
	All the patterns are processed in the specified order.

	If the first pattern that matches is an "exclude" one, the file
	is excluded. If it's an "include" one, the file is included.
	If no pattern matches, the file is excluded if the last pattern
	specified is an "include", or included if the last pattern
	specified is an "exclude".

	See the PATTERN section for more details in the pattern
	specifications.

	This option can be used many times.

  blocksize SIZE_IN_KIBIBYTES
	Defines the basic block size in kibi bytes of the parity.
	One kibi bytes is 1024 bytes. The default blocksize is 256
	and it should work for most cases.

	A reason to use a different blocksize is if your system has less
	than 4 GiB of memory. As a rule of thumb, with 4 GiB or more memory
	use the default 256, with 2 GiB use 512, and with 1 GiB use 1024.

	In more details SnapRAID requires about TS*28/BS bytes
	of RAM memory to run in the 32 bits version, and TS*36/BS
	in the 64 bits one. Where TS is the total size in bytes of
	your disk array, and BS is the block size in bytes.

	For example with 8 disk of 4 TB and a block size of 256 KiB
	(1 KiB = 1024 bytes) you have:

	:RAM = (8 * 4 * 10^12) * 28 / (256 * 2^10) = 3.2 GiB

	Another reason to use a different blocksize is if you have a lot of
	small files. In the order of many millions.

	For each file, even of few bytes, a whole block of parity is allocated,
	and with many files this may result in a lot of unused parity space.
	And when you completely fill the parity disk, you are not
	allowed to add more files in the data disks.
	Anyway, the wasted parity doesn't sum between data disks. Wasted space
	resulting from a high number of files in a data disk, limits only
	the amount of data in such data disk and not in others.

	As approximation, you can assume that half of the block size is
	wasted for each file. For example, with 100000 files and a 256 KiB
	block size, you are going to waste 13 GB of parity, that may result
	in 13 GB less space available in the data disk.

	You can get the amount of wasted space in each disk using "status".
	This is the amount of space that you must leave free in the data
	disks, or use for files not included in the array.
	If this value is negative, it means that your are near to fill
	the parity, and it represents the space you can still waste.

	To avoid the problem, you can use a bigger partition for parity.
	For example, if you have the parity partition bigger than 13 GB
	than data disks, you have enough extra space to handle up to 100000
	files in each data disk.

	A trick to get a bigger parity partition in Linux, is to format it
	with the command:

		:mkfs.ext4 -m 0 -T largefile4 DEVICE

	This results in about 1.5% of extra space. Meaning about 60 GB for
	a 4 TB disk, that allows about 460000 files in each data disk without
	any wasted space.

  autosave SIZE_IN_GIGABYTES
	Automatically save the state when syncing after the specified amount
	of GB processed.
	This option is useful to avoid to restart from scratch long "sync"
	commands interrupted by a machine crash, or any other event that
	may interrupt SnapRAID.

  pool DIR
	Defines the pooling directory where the virtual view of the disk
	array is created using the "pool" command.

	The directory must already exist.

  share UNC_DIR
	Defines the Windows UNC path required to access the disks remotely.

	If this option is specified, the symbolic links created in the pool
	directory use this UNC path to access the disks.
	Without this option the symbolic links generated use only local paths,
	not allowing to share the pool directory in the network.

	The symbolic links are formed using the specified UNC path, adding the
	disk name as specified in the "disk" option, and finally adding the
	file dir and name.

	This option is only required for Windows.

  smartctl DISK/PARITY OPTIONS...
	Defines a custom smartctl command to obtain the SMART attributes
	for each disk. This may be required for RAID controllers and for
	some USB disk that cannot be autodetected.

	DISK is the same disk name specified in the "disk" option.
	PARITY is one of the parity name as "parity,[1,2,3,4,5,6,z]-parity".

	In the specified OPTIONS, the "%s" string is replaced by the
	device name. Note that in case of RAID controllers the device is likely
	fixed, and you don't have to use "%s".

	Refers at the smartmontools documentation about the possible options:

		:https://www.smartmontools.org/wiki/Supported_RAID-Controllers
		:https://www.smartmontools.org/wiki/Supported_USB-Devices

  Examples
	An example of a typical configuration for Unix is:

		:parity /mnt/diskp/snapraid.parity
		:content /mnt/diskp/snapraid.content
		:content /var/snapraid/snapraid.content
		:disk d1 /mnt/disk1/
		:disk d2 /mnt/disk2/
		:disk d3 /mnt/disk3/
		:exclude /lost+found/
		:exclude /tmp/
		:smartctl d1 -d sat %s
		:smartctl d2 -d usbjmicron %s
		:smartctl parity -d areca,1/1 /dev/sg0
		:smartctl 2-parity -d areca,2/1 /dev/sg0

	An example of a typical configuration for Windows is:

		:parity E:\snapraid.parity
		:content E:\snapraid.content
		:content C:\snapraid\snapraid.content
		:disk d1 G:\array\
		:disk d2 H:\array\
		:disk d3 I:\array\
		:exclude Thumbs.db
		:exclude \$RECYCLE.BIN
		:exclude \System Volume Information
		:smartctl d1 -d sat %s
		:smartctl d2 -d usbjmicron %s
		:smartctl parity -d areca,1/1 /dev/arcmsr0
		:smartctl 2-parity -d areca,2/1 /dev/arcmsr0

Pattern
	Patterns are used to select a subset of files to exclude or include in
	the process.

	There are four different types of patterns:

	=FILE
		Selects any file named as FILE. You can use any globbing
		character like * and ?.
		This pattern is applied only to files and not to directories.

	=DIR/
		Selects any directory named DIR and everything inside.
		You can use any globbing character like * and ?.
		This pattern is applied only to directories and not to files.

	=/PATH/FILE
		Selects the exact specified file path. You can use any
		globbing character like * and ? but they never match a
		directory slash.
		This pattern is applied only to files and not to directories.

	=/PATH/DIR/
		Selects the exact specified directory path and everything
		inside. You can use any globbing character like * and ? but
		they never match a directory slash.
		This pattern is applied only to directories and not to files.

	Note that when you specify an absolute path starting with /, it's
	applied at the array root dir and not at the local filesystem root dir.

	In Windows you can use the backslash \ instead of the forward slash /.
	Note that Windows system directories, junctions, mount points, and any
	other Windows special directory are treated just as files, meaning that
	to exclude them you must use a file rule, and not a directory one.

	In the configuration file, you can use different strategies to filter
	the files to process.
	The simplest one is to use only "exclude" rules to remove all the
	files and directories you do not want to process. For example:

		:# Excludes any file named "*.unrecoverable"
		:exclude *.unrecoverable
		:# Excludes the root directory "/lost+found"
		:exclude /lost+found/
		:# Excludes any sub-directory named "tmp"
		:exclude tmp/

	The opposite way is to define only the file you want to process, using
	only "include" rules. For example:

		:# Includes only some directories
		:include /movies/
		:include /musics/
		:include /pictures/

	The final way, is to mix "exclude" and "include" rules. In this case take
	care that the order of rules is important. Previous rules have the
	precedence over the later ones.
	To get things simpler you can first have all the "exclude" rules and then
	all the "include" ones. For example:

		:# Excludes any file named "*.unrecoverable"
		:exclude *.unrecoverable
		:# Excludes any sub-directory named "tmp"
		:exclude tmp/
		:# Includes only some directories
		:include /movies/
		:include /musics/
		:include /pictures/

	On the command line, using the -f option, you can only use "include"
	patterns. For example:

		:# Checks only the .mp3 files.
		:# Note the "" use to avoid globbing expansion by the shell in Unix.
		:snapraid -f "*.mp3" check

	In Unix, when using globbing chars in the command line, you have to
	quote them. Otherwise the shell will try to expand them.

Content
	SnapRAID stores the list and checksums of your files in the content file.

	It's a binary file, listing all the files present in your disk array,
	with all the checksums to verify their integrity.

	This file is read and written by the "sync" and "scrub" commands, and
	read by "fix", "check" and "status".

Parity
	SnapRAID stores the parity information of your array in the parity
	files.

	They are binary files, containing the computed parity of all the
	blocks defined in the "content" file.

	These files are read and written by the "sync" and "fix" commands, and
	only read by "scrub" and "check".

Encoding
	SnapRAID in Unix ignores any encoding. It reads and stores the
	file names with the same encoding used by the filesystem.

	In Windows all the names read from the filesystem are converted and
	processed in the UTF-8 format.

	To have the file names printed correctly you have to set the Windows
	console in the UTF-8 mode, with the command "chcp 65001", and use
	a TrueType font like "Lucida Console" as console font.
	Note that it has effect only on the printed file names, if you
	redirect the console output to a file, the resulting file is always
	in the UTF-8 format.

Copyright
	This file is Copyright (C) 2011 Andrea Mazzoleni

See Also
	rsync(1)

