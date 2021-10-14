#!/bin/bash

# Download new torrents from Lostfilm
# Aleksej Kozlov <ovoled@gmail.com> 2021

rss_url="http://insearch.site/rssdd.xml"
base_url="http://n.tracktor.site/rssdownloader.php?id="
torrent_dir="torrents"
cookies_file="cookies"
torrent_list_file="torrents.lst"
data_file="lostfilm.dat"
temp_file="lostfilm.tmp"

function download_torrent {
	local url="$base_url$1"
	local out=`wget --content-disposition --load-cookies="$cookies_file" --directory-prefix="$torrent_dir" "$url" 2>&1`
	local res=$?
	[[ "$res" -eq "0" ]] || { echo "$out"; return $res; }
	local filename=`echo "$out" | grep "Saving to:" | sed -e "s/^Saving to: '//g" -e "s/'$//g"`
	[[ "$filename" =~ rssdownloader\.php@id=[0-9.]+$ ]] && { echo "$url: unexpected filename \"$filename\""; rm "$filename"; return 0; }
	local logstr="$url"$'\t'"\"$filename\""
	echo "$logstr"
	echo "$logstr" >> "$torrent_list_file"
	return 0
}

function main {
	local first_index
	[[ "$prev_max_index" == "" ]] && first_index="$min_index" || first_index=$(($prev_max_index+1))
	local i
	for (( i=$first_index; i <= $max_index; i++ ))
	do
		download_torrent "$i"
		local res=$?
		[[ "$res" -eq "0" ]] || { echo "error code $res"; exit $res; }
		echo "$i" >"$data_file"
	done
}

function get_indexes {
	local line
	IFS= read -r line <"$data_file"
	[[ "${line:$((${#line}-1))}" == $'\r' ]] && line=${line:0:$((${#line}-1))}
	[[ "$line" == +([0-9]) ]] && prev_max_index="$line" || prev_max_index=""

	min_index=2147483647
	max_index=0
	local out=`wget --output-document="$temp_file" --load-cookies="$cookies_file" "$rss_url" 2>&1`
	local res=$?
	[[ "$res" -eq "0" ]] || { echo "$out"; rm "$temp_file"; return $res; }
	while IFS= read -r line
	do
		if [[ "${line:0:${#base_url}}" == "$base_url" ]]
		then
			line="${line:${#base_url}}"
			[[ "${line:$((${#line}-1))}" == $'\r' ]] && line=${line:0:$((${#line}-1))}
			[[ "$line" == +([0-9]) ]] && [[ "$line" -gt "$max_index" ]] && max_index="$line"
			[[ "$line" == +([0-9]) ]] && [[ "$line" -lt "$min_index" ]] && min_index="$line"
		fi
	done < <(grep -e "<link>.*</link>" "$temp_file" | sed -r "s/.*<link>(.*)<[/]link.*>/\1/")
	rm "$temp_file"
}

mkdir --parents "$torrent_dir"
get_indexes
main
