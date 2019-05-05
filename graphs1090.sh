#!/bin/bash

DOCUMENTROOT=/run/graphs1090

renice -n 5 -p $$

mult() {
	echo $1 $2 | awk '{printf "%.3f", $1 * $2}'
}

ether="$(ls /var/lib/collectd/rrd/localhost | grep interface -m1)"
wifi="$(ls /var/lib/collectd/rrd/localhost | grep interface -m2 | tail -n1)"

disk="$(ls /var/lib/collectd/rrd/localhost | grep disk -m1)"

lwidth=1096
#1096 or 960
lheight=235
swidth=619
sheight=324

font_size=10.0
graph_size=default

source /etc/default/graphs1090

case $graph_size in
	custom)
		;;
	small)
		lwidth=960; lheight=206; swidth=543; sheight=276
		font_size=$(mult $font_size 0.92)
		;;
	large)
		lwidth=1260; lheight=271; swidth=702; sheight=362
		font_size=$(mult $font_size 1.08)
		;;
	huge)
		lwidth=1440; lheight=310; swidth=796; sheight=414
		font_size=$(mult $font_size 1.15)
		;;
	*|default)
		lwidth=1096; lheight=235; swidth=619; sheight=324
		;;
esac


fontsize="-n TITLE:$(mult 1.1 $font_size):. -n AXIS:$(mult 0.8 $font_size):. -n UNIT:$(mult 0.9 $font_size):. -n LEGEND:$(mult 0.9 $font_size):."
grid="-c GRID#FFFFFF --grid-dash 2:1"
options="$grid $fontsize"
small="$options -D --width $swidth --height $sheight"
big="$options --width $lwidth --height $lheight"

pre="sleep 0.3"

#checks a file name for existence and otherwise uses an "empty" rrd as a source so the graphs can still be printed even if the file is missing

check() {
	if [ -f $1 ]
	then
		echo $1
	else
		echo "File $1 not found! Associated graph will be empty!" 1>&2
		echo "/var/lib/collectd/rrd/$collectd_hostname/dump1090-$dump1090_instance/dump1090_dbfs-NaN.rrd"
	fi
}


## DUMP1090 GRAPHS

aircraft_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "$3 Aircraft Seen / Tracked" \
		--vertical-label "Aircraft" \
		--lower-limit 0 \
		--units-exponent 0 \
		"TEXTALIGN:center" \
		"DEF:all=$(check $2/dump1090_aircraft-recent.rrd):total:AVERAGE" \
		"DEF:pos=$(check $2/dump1090_aircraft-recent.rrd):positions:AVERAGE" \
		"DEF:mlat=$(check $2/dump1090_mlat-recent.rrd):value:AVERAGE" \
		"DEF:tisb=$(check $2/dump1090_tisb-recent.rrd):value:AVERAGE" \
		"CDEF:noloc=all,pos,-" \
		"VDEF:avgac=all,AVERAGE" \
		"VDEF:maxac=all,MAXIMUM" \
		"AREA:all#00FF00:Aircraft Seen / Tracked,   " \
		"GPRINT:avgac:Average\:%3.0lf     " \
		"GPRINT:maxac:Maximum\:%3.0lf\c" \
		"LINE1:pos#0000FF:w/ Position" \
		"LINE1:noloc#FF0000:w/o Position" \
		"LINE1:mlat#000000:MLAT" \
		"LINE1:tisb#00c0FF:TIS-B" \
		--watermark "Drawn: $nowlit";
	}

aircraft_message_rate_graph() {
	if [ -f $2/dump1090_messages-remote_accepted.rrd ]
	then messages="CDEF:messages=messages1,messages2,ADDNAN"
	else messages="CDEF:messages=messages1"
	fi
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "$3 Message Rate / Aircraft" \
		--vertical-label "Messages/Aircraft/Second" \
		--right-axis-label "Aircraft" \
		--lower-limit 0 \
		--units-exponent 0 \
		--right-axis 10:0 \
		"TEXTALIGN:center" \
		"DEF:aircrafts=$(check $2/dump1090_aircraft-recent.rrd):total:AVERAGE" \
		"DEF:messages1=$(check $2/dump1090_messages-local_accepted.rrd):value:AVERAGE" \
		"DEF:messages2=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE" \
		$messages \
		"CDEF:provisional=messages,aircrafts,/" \
		"CDEF:rate=aircrafts,0,GT,provisional,0,IF" \
		"CDEF:aircrafts10=aircrafts,10,/" \
		"VDEF:avgrate=rate,AVERAGE" \
		"VDEF:maxrate=rate,MAXIMUM" \
		"LINE1:rate#0000FF:Messages / AC" \
		"LINE1:avgrate#666666:Average:dashes" \
		"GPRINT:avgrate:%3.1lf" \
		"LINE1:maxrate#FF0000:Maximum" \
		"GPRINT:maxrate:%3.1lf\c" \
		"LINE1:aircrafts10#990000:Aircraft Seen / Tracked (RHS) \c" \
		--watermark "Drawn: $nowlit";
	}

cpu_graph_dump1090() {
	if [ -f $2/dump1090_cpu-airspy.rrd ]; then
		airspy_graph1="DEF:airspy=$2/dump1090_cpu-airspy.rrd:value:AVERAGE"
		airspy_graph2="CDEF:airspyp=airspy,10,/"
		airspy_graph3="AREA:airspyp#4169E1:Airspy"
	fi
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "$3 CPU Utilization" \
		--vertical-label "CPU %" \
		--lower-limit 0 \
		--rigid \
		"DEF:demod=$(check $2/dump1090_cpu-demod.rrd):value:AVERAGE" \
		"CDEF:demodp=demod,10,/" \
		"DEF:reader=$(check $2/dump1090_cpu-reader.rrd):value:AVERAGE" \
		"CDEF:readerp=reader,10,/" \
		"DEF:background=$(check $2/dump1090_cpu-background.rrd):value:AVERAGE" \
		"CDEF:backgroundp=background,10,/" \
		$airspy_graph1 \
		$airspy_graph2 \
		$airspy_graph3 \
		"AREA:readerp#008000:USB" \
		"AREA:backgroundp#00C000:Other:STACK" \
		"AREA:demodp#00FF00:Demodulator\c:STACK" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

tracks_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "$3 Tracks Seen" \
		--vertical-label "Tracks/Hour" \
		--lower-limit 0 \
		--units-exponent 0 \
		"DEF:all=$(check $2/dump1090_tracks-all.rrd):value:AVERAGE" \
		"DEF:single=$(check $2/dump1090_tracks-single_message.rrd):value:AVERAGE" \
		"CDEF:hall=all,3600,*" \
		"CDEF:hsingle=single,3600,*" \
		"CDEF:rhall=hall,300,TRENDNAN" \
		"CDEF:rsingle=hsingle,300,TRENDNAN" \
		"AREA:rsingle#FF0000:Tracks with single message" \
		"AREA:rhall#00FF00:Unique tracks\c:STACK" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

## SYSTEM GRAPHS

cpu_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$big \
		--step "$5" \
		--title "Overall CPU Utilization" \
		--vertical-label "CPU %" \
		--lower-limit 0 \
		--rigid \
		--units-exponent 0 \
		"DEF:idle=$(check $2/cpu-idle.rrd):value:AVERAGE" \
		"DEF:interrupt=$(check $2/cpu-interrupt.rrd):value:AVERAGE" \
		"DEF:nice=$(check $2/cpu-nice.rrd):value:AVERAGE" \
		"DEF:softirq=$(check $2/cpu-softirq.rrd):value:AVERAGE" \
		"DEF:steal=$(check $2/cpu-steal.rrd):value:AVERAGE" \
		"DEF:system=$(check $2/cpu-system.rrd):value:AVERAGE" \
		"DEF:user=$(check $2/cpu-user.rrd):value:AVERAGE" \
		"DEF:wait=$(check $2/cpu-wait.rrd):value:AVERAGE" \
		"CDEF:all=idle,interrupt,nice,softirq,steal,system,user,wait,+,+,+,+,+,+,+" \
		"CDEF:pinterrupt=100,interrupt,*,all,/" \
		"CDEF:pnice=100,nice,*,all,/" \
		"CDEF:psoftirq=100,softirq,*,all,/" \
		"CDEF:psteal=100,steal,*,all,/" \
		"CDEF:psystem=100,system,*,all,/" \
		"CDEF:puser=100,user,*,all,/" \
		"CDEF:pwait=100,wait,*,all,/" \
		"AREA:pinterrupt#000080:irq" \
		"AREA:psoftirq#0000C0:softirq:STACK" \
		"AREA:psteal#0000FF:steal:STACK" \
		"AREA:pwait#C00000:io:STACK" \
		"AREA:psystem#FF0000:sys:STACK" \
		"AREA:puser#40FF40:user:STACK" \
		"AREA:pnice#008000:nice\c:STACK" \
		--watermark "Drawn: $nowlit";
	}

df_root_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "Disk Usage (/)" \
		--vertical-label "" \
		--lower-limit 0  \
		"TEXTALIGN:center" \
		"DEF:used=$(check $2/df_complex-used.rrd):value:AVERAGE" \
		"DEF:reserved=$(check $2/df_complex-reserved.rrd):value:AVERAGE" \
		"DEF:free=$(check $2/df_complex-free.rrd):value:AVERAGE" \
		"CDEF:totalused=used,reserved,+" \
		"AREA:totalused#4169E1:Used:STACK" \
		"AREA:free#32C734:Free\c:STACK" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

disk_io_iops_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "Disk I/O - IOPS" \
		--vertical-label "IOPS" \
		"TEXTALIGN:center" \
		"DEF:read=$(check $2/disk_ops.rrd):read:AVERAGE" \
		"DEF:write=$(check $2/disk_ops.rrd):write:AVERAGE" \
		"CDEF:write_neg=write,-1,*" \
		"AREA:read#32CD32:Reads " \
		"LINE1:read#336600" \
		"GPRINT:read:MAX:Max\:%4.1lf iops" \
		"GPRINT:read:AVERAGE:Avg\:%4.1lf iops" \
		"GPRINT:read:LAST:Current\:%4.1lf iops\c" \
		"TEXTALIGN:center" \
		"AREA:write_neg#4169E1:Writes" \
		"LINE1:write_neg#0033CC" \
		"GPRINT:write:MAX:Max\:%4.1lf iops" \
		"GPRINT:write:AVERAGE:Avg\:%4.1lf iops" \
		"GPRINT:write:LAST:Current\:%4.1lf iops\c" \
		--watermark "Drawn: $nowlit";
	}

disk_io_octets_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "Disk I/O - Bandwidth" \
		--vertical-label "Bytes/Sec" \
		"TEXTALIGN:center" \
		"DEF:read=$(check $2/disk_octets.rrd):read:AVERAGE" \
		"DEF:write=$(check $2/disk_octets.rrd):write:AVERAGE" \
		"CDEF:write_neg=write,-1,*" \
		"AREA:read#32CD32:Reads " \
		"LINE1:read#336600" \
		"GPRINT:read:MAX:Max\: %4.1lf %sB/sec" \
		"GPRINT:read:AVERAGE:Avg\: %4.1lf %SB/sec" \
		"GPRINT:read:LAST:Current\: %4.1lf %SB/sec\c" \
		"TEXTALIGN:center" \
		"AREA:write_neg#4169E1:Writes" \
		"LINE1:write_neg#0033CC" \
		"GPRINT:write:MAX:Max\: %4.1lf %sB/sec" \
		"GPRINT:write:AVERAGE:Avg\: %4.1lf %SB/sec" \
		"GPRINT:write:LAST:Current\: %4.1lf %SB/sec\c" \
		--watermark "Drawn: $nowlit";
	}

eth0_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "Bandwidth Usage (eth0)" \
		--vertical-label "Bytes/Sec" \
		"TEXTALIGN:center" \
		"DEF:rx=$(check $2/if_octets.rrd):rx:AVERAGE" \
		"DEF:tx=$(check $2/if_octets.rrd):tx:AVERAGE" \
		"CDEF:tx_neg=tx,-1,*" \
		"AREA:rx#32CD32:Incoming" \
		"LINE1:rx#336600" \
		"GPRINT:rx:MAX:Max\:%8.1lf %s" \
		"GPRINT:rx:AVERAGE:Avg\:%8.1lf %S" \
		"GPRINT:rx:LAST:Current\:%8.1lf %Sbytes/sec\c" \
		"AREA:tx_neg#4169E1:Outgoing" \
		"LINE1:tx_neg#0033CC" \
		"GPRINT:tx:MAX:Max\:%8.1lf %S" \
		"GPRINT:tx:AVERAGE:Avg\:%8.1lf %S" \
		"GPRINT:tx:LAST:Current\:%8.1lf %Sbytes/sec\c" \
		--watermark "Drawn: $nowlit";
	}

memory_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--lower-limit 0 \
		--title "Memory Utilization" \
		--vertical-label "" \
		"TEXTALIGN:center" \
		"DEF:buffered=$(check $2/memory-buffered.rrd):value:AVERAGE" \
		"DEF:cached=$(check $2/memory-cached.rrd):value:AVERAGE" \
		"DEF:free=$(check $2/memory-free.rrd):value:AVERAGE" \
		"DEF:used=$(check $2/memory-used.rrd):value:AVERAGE" \
		"AREA:used#4169E1:Used:STACK" \
		"AREA:buffered#32C734:Buffered:STACK" \
		"AREA:cached#00FF00:Cached:STACK" \
		"AREA:free#FFFFFF:Free\c:STACK" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}


network_graph() {
	if [[ $(ls /var/lib/collectd/rrd/localhost | grep interface -c) < 2 ]]
	then
		interfaces=(\
			"DEF:rx=$(check $2/$ether/if_octets.rrd):rx:AVERAGE" \
			"DEF:tx=$(check $2/$ether/if_octets.rrd):tx:AVERAGE" )
	else
		interfaces=(\
			"DEF:rx1=$(check $2/$wifi/if_octets.rrd):rx:AVERAGE" \
			"DEF:tx1=$(check $2/$wifi/if_octets.rrd):tx:AVERAGE" \
			"DEF:rx2=$(check $2/$ether/if_octets.rrd):rx:AVERAGE" \
			"DEF:tx2=$(check $2/$ether/if_octets.rrd):tx:AVERAGE" \
			"CDEF:rx=rx1,rx2,ADDNAN" \
			"CDEF:tx=tx1,tx2,ADDNAN")
	fi
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		-Z --step "$5" \
		--title "Bandwidth Usage (wireless + ethernet)" \
		--vertical-label "Bytes/Sec" \
		"TEXTALIGN:center" \
		"${interfaces[@]}" \
		"CDEF:tx_neg=tx,-1,*" \
		"AREA:rx#32CD32:Incoming" \
		"LINE1:rx#336600" \
		"GPRINT:rx:MAX:Max\:%8.1lf %s" \
		"GPRINT:rx:AVERAGE:Avg\:%8.1lf %S" \
		"GPRINT:rx:LAST:Current\:%8.1lf %Sbytes/sec\c" \
		"AREA:tx_neg#4169E1:Outgoing" \
		"LINE1:tx_neg#0033CC" \
		"GPRINT:tx:MAX:Max\:%8.1lf %S" \
		"GPRINT:tx:AVERAGE:Avg\:%8.1lf %S" \
		"GPRINT:tx:LAST:Current\:%8.1lf %Sbytes/sec\c" \
		--watermark "Drawn: $nowlit";
	}

temp_graph_imperial() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "Core Temperature" \
		--vertical-label "Degrees Fahrenheit" \
		--lower-limit 32 \
		--upper-limit 212 \
		--rigid \
		--units-exponent 1 \
		"DEF:traw=$(check $2/gauge-cpu_temp.rrd):value:MAX" \
		"CDEF:tta=traw,1000,/" \
		"CDEF:ttb=tta,1.8,*" \
		"CDEF:ttc=ttb,32,+" \
		"AREA:ttc#ffcc00" \
		"COMMENT: \n" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

temp_graph_metric() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "Core Temperature" \
		--vertical-label "Degrees Celcius" \
		--lower-limit 0 \
		--upper-limit 100 \
		--rigid \
		--units-exponent 1 \
		"DEF:traw=$(check $2/gauge-cpu_temp.rrd):value:MAX" \
		"CDEF:tfin=traw,1000,/" \
		"AREA:tfin#ffcc00" \
		"COMMENT: \n" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

wlan0_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "Bandwidth Usage (wlan0)" \
		--vertical-label "Bytes/Sec" \
		"TEXTALIGN:center" \
		"DEF:rx=$(check $2/if_octets.rrd):rx:AVERAGE" \
		"DEF:tx=$(check $2/if_octets.rrd):tx:AVERAGE" \
		"CDEF:tx_neg=tx,-1,*" \
		"AREA:rx#32CD32:Incoming" \
		"LINE1:rx#336600" \
		"GPRINT:rx:MAX:Max\:%8.1lf %s" \
		"GPRINT:rx:AVERAGE:Avg\:%8.1lf %S" \
		"GPRINT:rx:LAST:Current\:%8.1lf %Sbytes/sec\c" \
		"AREA:tx_neg#4169E1:Outgoing" \
		"LINE1:tx_neg#0033CC" \
		"GPRINT:tx:MAX:Max\:%8.1lf %S" \
		"GPRINT:tx:AVERAGE:Avg\:%8.1lf %S" \
		"GPRINT:tx:LAST:Current\:%8.1lf %Sbytes/sec\c" \
		--watermark "Drawn: $nowlit";
	}

## RECEIVER GRAPHS

local_rate_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "$3 Message Rate" \
		--vertical-label "Messages/Second" \
		--lower-limit 0  \
		--units-exponent 0 \
		--right-axis 360:0 \
		"DEF:messages1=$(check $2/dump1090_messages-local_accepted.rrd):value:AVERAGE" \
		"DEF:messages2=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE" \
		"DEF:strong=$(check $2/dump1090_messages-strong_signals.rrd):value:AVERAGE" \
		"DEF:positions=$(check $2/dump1090_messages-positions.rrd):value:AVERAGE" \
		"CDEF:y2positions=positions,10,*" \
		"LINE1:messages1#0000FF:Local" \
		"LINE1:messages2#009900:Remote" \
		"AREA:strong#FF0000:Messages > -3dBFS" \
		"LINE1:y2positions#00c0FF:Positions / Hr (RHS)\c" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

local_trailing_rate_graph() {
	if [ -f $2/dump1090_messages-remote_accepted.rrd ]
	then messages="CDEF:messages=messages1,messages2,ADDNAN"
	else messages="CDEF:messages=messages1"
	fi
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$big \
		--slope-mode \
		--step "$5" \
		--title "$3 Message Rate" \
		--vertical-label "Messages/Second" \
		--lower-limit 0  \
		--units-exponent 0 \
		--right-axis 0.1:0 \
		--pango-markup \
		"TEXTALIGN:center" \
		"DEF:messages1=$(check $2/dump1090_messages-local_accepted.rrd):value:AVERAGE" \
		"DEF:a1=$(check $2/dump1090_messages-local_accepted.rrd):value:AVERAGE:end=now-86400:start=end-86400" \
		"DEF:b1=$(check $2/dump1090_messages-local_accepted.rrd):value:AVERAGE:end=now-172800:start=end-86400" \
		"DEF:c1=$(check $2/dump1090_messages-local_accepted.rrd):value:AVERAGE:end=now-259200:start=end-86400" \
		"DEF:d1=$(check $2/dump1090_messages-local_accepted.rrd):value:AVERAGE:end=now-345600:start=end-86400" \
		"DEF:e1=$(check $2/dump1090_messages-local_accepted.rrd):value:AVERAGE:end=now-432000:start=end-86400" \
		"DEF:f1=$(check $2/dump1090_messages-local_accepted.rrd):value:AVERAGE:end=now-518400:start=end-86400" \
		"DEF:g1=$(check $2/dump1090_messages-local_accepted.rrd):value:AVERAGE:end=now-604800:start=end-86400" \
		"DEF:amin1=$(check $2/dump1090_messages-local_accepted.rrd):value:MIN:end=now-86400:start=end-86400" \
		"DEF:bmin1=$(check $2/dump1090_messages-local_accepted.rrd):value:MIN:end=now-172800:start=end-86400" \
		"DEF:cmin1=$(check $2/dump1090_messages-local_accepted.rrd):value:MIN:end=now-259200:start=end-86400" \
		"DEF:dmin1=$(check $2/dump1090_messages-local_accepted.rrd):value:MIN:end=now-345600:start=end-86400" \
		"DEF:emin1=$(check $2/dump1090_messages-local_accepted.rrd):value:MIN:end=now-432000:start=end-86400" \
		"DEF:fmin1=$(check $2/dump1090_messages-local_accepted.rrd):value:MIN:end=now-518400:start=end-86400" \
		"DEF:gmin1=$(check $2/dump1090_messages-local_accepted.rrd):value:MIN:end=now-604800:start=end-86400" \
		"DEF:amax1=$(check $2/dump1090_messages-local_accepted.rrd):value:MAX:end=now-86400:start=end-86400" \
		"DEF:bmax1=$(check $2/dump1090_messages-local_accepted.rrd):value:MAX:end=now-172800:start=end-86400" \
		"DEF:cmax1=$(check $2/dump1090_messages-local_accepted.rrd):value:MAX:end=now-259200:start=end-86400" \
		"DEF:dmax1=$(check $2/dump1090_messages-local_accepted.rrd):value:MAX:end=now-345600:start=end-86400" \
		"DEF:emax1=$(check $2/dump1090_messages-local_accepted.rrd):value:MAX:end=now-432000:start=end-86400" \
		"DEF:fmax1=$(check $2/dump1090_messages-local_accepted.rrd):value:MAX:end=now-518400:start=end-86400" \
		"DEF:gmax1=$(check $2/dump1090_messages-local_accepted.rrd):value:MAX:end=now-604800:start=end-86400" \
		"DEF:messages2=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE" \
		"DEF:a2=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE:end=now-86400:start=end-86400" \
		"DEF:b2=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE:end=now-172800:start=end-86400" \
		"DEF:c2=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE:end=now-259200:start=end-86400" \
		"DEF:d2=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE:end=now-345600:start=end-86400" \
		"DEF:e2=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE:end=now-432000:start=end-86400" \
		"DEF:f2=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE:end=now-518400:start=end-86400" \
		"DEF:g2=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE:end=now-604800:start=end-86400" \
		"DEF:amin2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MIN:end=now-86400:start=end-86400" \
		"DEF:bmin2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MIN:end=now-172800:start=end-86400" \
		"DEF:cmin2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MIN:end=now-259200:start=end-86400" \
		"DEF:dmin2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MIN:end=now-345600:start=end-86400" \
		"DEF:emin2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MIN:end=now-432000:start=end-86400" \
		"DEF:fmin2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MIN:end=now-518400:start=end-86400" \
		"DEF:gmin2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MIN:end=now-604800:start=end-86400" \
		"DEF:amax2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MAX:end=now-86400:start=end-86400" \
		"DEF:bmax2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MAX:end=now-172800:start=end-86400" \
		"DEF:cmax2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MAX:end=now-259200:start=end-86400" \
		"DEF:dmax2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MAX:end=now-345600:start=end-86400" \
		"DEF:emax2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MAX:end=now-432000:start=end-86400" \
		"DEF:fmax2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MAX:end=now-518400:start=end-86400" \
		"DEF:gmax2=$(check $2/dump1090_messages-remote_accepted.rrd):value:MAX:end=now-604800:start=end-86400" \
		$messages \
		"CDEF:a=a1,a2,ADDNAN" \
		"CDEF:b=b1,b2,ADDNAN" \
		"CDEF:c=c1,c2,ADDNAN" \
		"CDEF:d=d1,d2,ADDNAN" \
		"CDEF:e=e1,e2,ADDNAN" \
		"CDEF:f=f1,f2,ADDNAN" \
		"CDEF:g=g1,g2,ADDNAN" \
		"CDEF:amin=amin1,amin2,ADDNAN" \
		"CDEF:bmin=bmin1,bmin2,ADDNAN" \
		"CDEF:cmin=cmin1,cmin2,ADDNAN" \
		"CDEF:dmin=dmin1,dmin2,ADDNAN" \
		"CDEF:emin=emin1,emin2,ADDNAN" \
		"CDEF:fmin=fmin1,fmin2,ADDNAN" \
		"CDEF:gmin=gmin1,gmin2,ADDNAN" \
		"CDEF:amax=amax1,amax2,ADDNAN" \
		"CDEF:bmax=bmax1,bmax2,ADDNAN" \
		"CDEF:cmax=cmax1,cmax2,ADDNAN" \
		"CDEF:dmax=dmax1,dmax2,ADDNAN" \
		"CDEF:emax=emax1,emax2,ADDNAN" \
		"CDEF:fmax=fmax1,fmax2,ADDNAN" \
		"CDEF:gmax=gmax1,gmax2,ADDNAN" \
		"CDEF:a3=a,UN,0,a,IF" \
		"CDEF:b3=b,UN,0,b,IF" \
		"CDEF:c3=c,UN,0,c,IF" \
		"CDEF:d3=d,UN,0,d,IF" \
		"CDEF:e3=e,UN,0,e,IF" \
		"CDEF:f3=f,UN,0,f,IF" \
		"CDEF:g3=g,UN,0,g,IF" \
		"DEF:strong=$(check $2/dump1090_messages-strong_signals.rrd):value:AVERAGE" \
		"DEF:positions=$(check $2/dump1090_messages-positions.rrd):value:AVERAGE" \
		"CDEF:y2positions=positions,10,*" \
		"VDEF:strong_total=strong,TOTAL" \
		"VDEF:messages_total=messages,TOTAL" \
		"CDEF:hundred=messages,UN,100,100,IF" \
		"CDEF:strong_percent=strong_total,hundred,*,messages_total,/" \
		"VDEF:strong_percent_vdef=strong_percent,LAST" \
		"SHIFT:a3:86400" \
		"SHIFT:b3:172800" \
		"SHIFT:c3:259200" \
		"SHIFT:d3:345600" \
		"SHIFT:e3:432000" \
		"SHIFT:f3:518400" \
		"SHIFT:g3:604800" \
		"SHIFT:amin:86400" \
		"SHIFT:bmin:172800" \
		"SHIFT:cmin:259200" \
		"SHIFT:dmin:345600" \
		"SHIFT:emin:432000" \
		"SHIFT:fmin:518400" \
		"SHIFT:gmin:604800" \
		"SHIFT:amax:86400" \
		"SHIFT:bmax:172800" \
		"SHIFT:cmax:259200" \
		"SHIFT:dmax:345600" \
		"SHIFT:emax:432000" \
		"SHIFT:fmax:518400" \
		"SHIFT:gmax:604800" \
		"CDEF:7dayaverage=a3,b3,c3,d3,e3,f3,g3,+,+,+,+,+,+,7,/" \
		"CDEF:min1=amin,bmin,MINNAN" \
		"CDEF:min2=cmin,dmin,MINNAN" \
		"CDEF:min3=emin,fmin,MINNAN" \
		"CDEF:min4=min1,min2,MINNAN" \
		"CDEF:min5=min3,gmin,MINNAN" \
		"CDEF:min=min4,min5,MINNAN" \
		"CDEF:max1=amax,bmax,MAXNAN" \
		"CDEF:max2=cmax,dmax,MAXNAN" \
		"CDEF:max3=emax,fmax,MAXNAN" \
		"CDEF:max4=max1,max2,MAXNAN" \
		"CDEF:max5=max3,gmax,MAXNAN" \
		"CDEF:max=max4,max5,MAXNAN" \
		"CDEF:maxarea=max,min,-" \
		"LINE0.01:messages#0000FF:Messages Received" \
		"LINE1:min#FFFF99" \
		"AREA:maxarea#FFFF99:Min/Max:STACK" \
		"LINE1:7dayaverage#00FF00:7 Day Average" \
		"LINE1:messages#0000FF" \
		"AREA:strong#FF0000:Messages > -3dBFS\g" \
		"GPRINT:strong_percent_vdef: (%1.1lf<span font='2'> </span>%% of messages)" \
		"LINE1:y2positions#00c0FF:Positions/s (RHS)\c" \
		--watermark "Drawn: $nowlit";
	}

range_graph_imperial_nautical(){
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "$3 Max Range" \
		--vertical-label "Nautical Miles" \
		--units-exponent 0 \
		--right-axis 1.852:0 \
		--right-axis-label "Kilometres" \
		"DEF:rangem=$(check $2/dump1090_range-max_range.rrd):value:MAX" \
		"CDEF:rangekm=rangem,0.001,*" \
		"CDEF:rangenm=rangekm,0.539956803,*" \
		"LINE1:rangenm#0000FF:Max Range" \
		"VDEF:avgrange=rangenm,AVERAGE" \
		"LINE1:avgrange#666666:Avr Range\\::dashes" \
		"VDEF:peakrange=rangenm,MAXIMUM" \
		"GPRINT:avgrange:%1.1lf NM" \
		"LINE1:peakrange#FF0000:Peak Range\\:" \
		"GPRINT:peakrange:%1.1lf NM\c" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

range_graph_imperial_statute(){
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "$3 Max Range" \
		--vertical-label "Statute Miles" \
		--units-exponent 0 \
		--right-axis 1.609:0 \
		--right-axis-label "Kilometres" \
		"DEF:rangem=$(check $2/dump1090_range-max_range.rrd):value:MAX" \
		"CDEF:rangekm=rangem,0.001,*" \
		"CDEF:rangesm=rangekm,0.621371,*" \
		"LINE1:rangesm#0000FF:Max Range" \
		"VDEF:avgrange=rangesm,AVERAGE" \
		"LINE1:avgrange#666666:Avr Range\\::dashes" \
		"VDEF:peakrange=rangesm,MAXIMUM" \
		"GPRINT:avgrange:%1.1lf SM" \
		"LINE1:peakrange#FF0000:Peak Range\\:" \
		"GPRINT:peakrange:%1.1lf SM\c" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

range_graph_metric() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "$3 Max Range" \
		--vertical-label "Kilometres" \
		--units-exponent 0 \
		--right-axis 0.5399:0 \
		--right-axis-label "Nautical Miles" \
		"DEF:rangem=$(check $2/dump1090_range-max_range.rrd):value:MAX" \
		"CDEF:range=rangem,0.001,*" \
		"LINE1:range#0000FF:Max Range" \
		"VDEF:avgrange=range,AVERAGE" \
		"LINE1:avgrange#666666:Avg Range\\::dashes" \
		"VDEF:peakrange=range,MAXIMUM" \
		"GPRINT:avgrange:%1.1lf km" \
		"LINE1:peakrange#FF0000:Peak Range\\:" \
		"GPRINT:peakrange:%1.1lf km\c" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

signal_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "$3 Signal Level" \
		--vertical-label "dBFS" \
		--upper-limit 1    \
		--lower-limit -45 \
		--rigid \
		--units-exponent 0 \
		"TEXTALIGN:center" \
		"DEF:signal=$(check $2/dump1090_dbfs-signal.rrd):value:AVERAGE" \
		"DEF:peak=$(check $2/dump1090_dbfs-peak_signal.rrd):value:AVERAGE" \
		"DEF:noise=$(check $2/dump1090_dbfs-noise.rrd):value:AVERAGE" \
		"CDEF:us=signal,UN,-100,signal,IF" \
		"AREA:-100#00FF00:Mean Level\\:" \
		"AREA:us#FFFFFF" \
		"GPRINT:signal:AVERAGE:%4.1lf" \
		"LINE1:peak#0000FF:Peak Level\:" \
		"GPRINT:peak:MAX:%4.1lf\c" \
		"LINE:noise#7F00FF:Noise" \
		"GPRINT:noise:MAX:Max\: %4.1lf" \
		"GPRINT:noise:MIN:Min\: %4.1lf" \
		"GPRINT:noise:AVERAGE:Avg\: %4.1lf\c" \
		"LINE1:0#000000:Zero dBFS" \
		"LINE1:-3#FF0000:-3 dBFS\c" \
		--watermark "Drawn: $nowlit";
	}

978_aircraft() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "UAT Aircraft Seen / Tracked" \
		--vertical-label "Aircraft" \
		--lower-limit 0 \
		--units-exponent 0 \
		"TEXTALIGN:center" \
		"DEF:all=$2/dump1090_aircraft-recent_978.rrd:total:AVERAGE" \
		"DEF:pos=$2/dump1090_aircraft-recent_978.rrd:positions:AVERAGE" \
		"DEF:tisb=$(check $2/dump1090_tisb-recent_978.rrd):value:AVERAGE" \
		"CDEF:noloc=all,pos,-" \
		"VDEF:avgac=all,AVERAGE" \
		"VDEF:maxac=all,MAXIMUM" \
		"AREA:all#00FF00:Aircraft Seen / Tracked,   " \
		"GPRINT:avgac:Average\:%3.0lf     " \
		"GPRINT:maxac:Maximum\:%3.0lf\c" \
		"LINE1:pos#0000FF:w/ Position" \
		"LINE1:noloc#FF0000:w/o Position" \
		"LINE1:tisb#00c0FF:TIS-B" \
		--watermark "Drawn: $nowlit";
	}

978_range(){ $pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "UAT Max Range" \
		--vertical-label "Nautical Miles" \
		--units-exponent 0 \
		--right-axis 1.852:0 \
		--right-axis-label "Kilometres" \
		"DEF:rangem=$2/dump1090_range-max_range_978.rrd:value:MAX" \
		"CDEF:rangekm=rangem,0.001,*" \
		"CDEF:rangenm=rangekm,0.539956803,*" \
		"LINE1:rangenm#0000FF:Max Range" \
		"VDEF:avgrange=rangenm,AVERAGE" \
		"LINE1:avgrange#666666:Avr Range\\::dashes" \
		"VDEF:peakrange=rangenm,MAXIMUM" \
		"GPRINT:avgrange:%1.1lf NM" \
		"LINE1:peakrange#FF0000:Peak Range\\:" \
		"GPRINT:peakrange:%1.1lf NM\c" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

978_messages() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "UAT Message Rate" \
		--vertical-label "Messages/Second" \
		--lower-limit 0  \
		--units-exponent 0 \
		--right-axis 1:0 \
		--right-axis-format "%.1lf" \
		--left-axis-format "%.1lf" \
		"DEF:messages1=$2/dump1090_messages-messages_978.rrd:value:AVERAGE" \
		"LINE1:messages1#0000FF:Messages\c" \
		"COMMENT: \n" \
		--watermark "Drawn: $nowlit";
	}

## HUB GRAPHS

remote_rate_graph() {
	$pre; rrdtool graph \
		"$1" \
		--start end-$4 \
		$small \
		--step "$5" \
		--title "$3 Message Rate" \
		--vertical-label "messages/second" \
		--lower-limit 0  \
		--units-exponent 0 \
		--right-axis 360:0 \
		"DEF:messages=$(check $2/dump1090_messages-remote_accepted.rrd):value:AVERAGE" \
		"DEF:positions=$(check $2/dump1090_messages-positions.rrd):value:AVERAGE" \
		"CDEF:y2positions=positions,10,*" \
		"LINE1:messages#0000FF:messages received" \
		"LINE1:y2positions#00c0FF:position / hr (RHS)" \
		--watermark "Drawn: $nowlit";
	}


dump1090_graphs() {
	aircraft_graph ${DOCUMENTROOT}/dump1090-$2-aircraft-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
	aircraft_message_rate_graph ${DOCUMENTROOT}/dump1090-$2-aircraft_message_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
	cpu_graph_dump1090 ${DOCUMENTROOT}/dump1090-$2-cpu-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
	tracks_graph ${DOCUMENTROOT}/dump1090-$2-tracks-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5" 
}

system_graphs() {
	cpu_graph ${DOCUMENTROOT}/system-$2-cpu-$4.png /var/lib/collectd/rrd/$1/aggregation-cpu-average "$3" "$4" "$5"
	df_root_graph ${DOCUMENTROOT}/system-$2-df_root-$4.png /var/lib/collectd/rrd/$1/df-root "$3" "$4" "$5"
	disk_io_iops_graph ${DOCUMENTROOT}/system-$2-disk_io_iops-$4.png /var/lib/collectd/rrd/$1/$disk "$3" "$4" "$5"
	disk_io_octets_graph ${DOCUMENTROOT}/system-$2-disk_io_octets-$4.png /var/lib/collectd/rrd/$1/$disk "$3" "$4" "$5"
	#eth0_graph ${DOCUMENTROOT}/system-$2-eth0_bandwidth-$4.png /var/lib/collectd/rrd/$1/$ether "$3" "$4" "$5"
	memory_graph ${DOCUMENTROOT}/system-$2-memory-$4.png /var/lib/collectd/rrd/$1/memory "$3" "$4" "$5"
	network_graph ${DOCUMENTROOT}/system-$2-network_bandwidth-$4.png /var/lib/collectd/rrd/$1 "$3" "$4" "$5"
	if [[ $farenheit == 1 ]]
	then
		temp_graph_imperial ${DOCUMENTROOT}/system-$2-temperature-$4.png /var/lib/collectd/rrd/$1/table-$2 "$3" "$4" "$5"
	else
		temp_graph_metric ${DOCUMENTROOT}/system-$2-temperature-$4.png /var/lib/collectd/rrd/$1/table-$2 "$3" "$4" "$5"
	fi
	#wlan0_graph ${DOCUMENTROOT}/system-$2-wlan0_bandwidth-$4.png /var/lib/collectd/rrd/$1/$wifi "$3" "$4" "$5"
}

dump1090_receiver_graphs() {
	dump1090_graphs "$1" "$2" "$3" "$4" "$5"
	system_graphs "$1" "$2" "$3" "$4" "$5"
	local_rate_graph ${DOCUMENTROOT}/dump1090-$2-local_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
	local_trailing_rate_graph ${DOCUMENTROOT}/dump1090-$2-local_trailing_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
	if [[ $range == "statute" ]]
	then
		range_graph_imperial_statute ${DOCUMENTROOT}/dump1090-$2-range-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
	elif [[ $range == "metric" ]]
	then
		range_graph_metric ${DOCUMENTROOT}/dump1090-$2-range-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
	else
		range_graph_imperial_nautical ${DOCUMENTROOT}/dump1090-$2-range-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
	fi
	signal_graph ${DOCUMENTROOT}/dump1090-$2-signal-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
	if [ -f /var/lib/collectd/rrd/$1/dump1090-$2/dump1090_messages-messages_978.rrd ]
	then
		978_range ${DOCUMENTROOT}/dump1090-$2-range_978-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
		978_aircraft ${DOCUMENTROOT}/dump1090-$2-aircraft_978-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
		978_messages ${DOCUMENTROOT}/dump1090-$2-messages_978-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
	fi
}

dump1090_hub_graphs() {
	dump1090_graphs "$1" "$2" "$3" "$4" "$5"
	system_graphs "$1" "$2" "$3" "$4" "$5"
	remote_rate_graph ${DOCUMENTROOT}/dump1090-$2-remote_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
}

period="$1"
step="$2"
nowlit=`date '+%Y-%m-%d %H:%M %Z'`;

# Changing the following two variables means you need to change the names in html/graph.js as well so that the graphs are correctly displayed
dump1090_instance="localhost"
collectd_hostname="localhost"

if [ -z $1 ]
then
	dump1090_receiver_graphs $collectd_hostname $dump1090_instance "ADS-B" "24h" "$step"
else
	dump1090_receiver_graphs $collectd_hostname $dump1090_instance "ADS-B" "$period" "$step"
fi
#hub_graphs localhost rpi "ADS-B" "$period" "$step"
