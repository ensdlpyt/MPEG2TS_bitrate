#! /usr/bin/bash

#bc -l 
#ibase=16 
#obase=F 
#

# Arguments
# $1 ts file
# $2 pcr pid

hex="[0-9A-F]"
hex_1_t="[13579BDF]" #contains bit 1
hex_1_f="[02468ACE]" #does not contain bit 1
hex_2_t="[2367ABEF]" #contains bit 2

pcrpid=$(($2))
echo "PCR_PID: ${pcrpid}"
pcrpid_hex=$(echo 16o${pcrpid}p | dc)
echo "PCR_PID: 0x${pcrpid_hex}"

if ((8191 <= $pcrpid))
then
	pid_1st_nibble=$hex_1_t
else
	pid_1st_nibble=$hex_1_f
fi

pid_last3_nibbles=$(printf "%03x" 0x$pcrpid_hex)
#echo $pid_last3_nibbles


output=$(xxd -p -c 188 $1 | grep -P -oni "^47${pid_1st_nibble}${pid_last3_nibbles}${hex_2_t}...${hex_1_t}.${hex}{12}" | sed -n '1p;$p' | sed -e 's/:.\{12\}/:/')

#echo $output;

shopt -s nocasematch
poorregex='^([0-9A-F]+):([0-9A-F]{8})([0-9A-F])([0-9A-F])([0-9A-F]{2})(\s|\n)([0-9A-F]+):([0-9A-F]{8})([0-9A-F])([0-9A-F])([0-9A-F]{2})' #I think now I have 3 problems
if [[ $output =~ $poorregex ]]
then 
	packet_a=${BASH_REMATCH[1]}
	pcr_base_32bit_a=${BASH_REMATCH[2]}
	pcr_base_lastbit_a=${BASH_REMATCH[3]}
	pcr_ext_firstbit_a=${BASH_REMATCH[4]}
	pcr_ext_8bit_a=${BASH_REMATCH[5]}
	packet_b=${BASH_REMATCH[7]}
	pcr_base_32bit_b=${BASH_REMATCH[8]}
	pcr_base_lastbit_b=${BASH_REMATCH[9]}
	pcr_ext_firstbit_b=${BASH_REMATCH[10]}
	pcr_ext_8bit_b=${BASH_REMATCH[11]}

#	echo "$packet_a, $pcr_base_32bit_a, $pcr_base_lastbit_a, $pcr_ext_firstbit_a, $pcr_ext_8bit_a"
#	echo "$packet_b, $pcr_base_32bit_b, $pcr_base_lastbit_b, $pcr_ext_firstbit_b, $pcr_ext_8bit_b"
else
	echo "Could not parse"
	exit 1;
fi
shopt -u nocasematch

hex_prefix="0x"

if ((8 <= ${hex_prefix}${pcr_base_lastbit_a}))
then
	pcr_base_a=$((${hex_prefix}${pcr_base_32bit_a} * 2 + 1))
else
	pcr_base_a=$((${hex_prefix}${pcr_base_32bit_a} * 2))
fi
#echo "pcr_base_a: ${pcr_base_a}"

shopt -s nocasematch
if [[ ${pcr_ext_firstbit_a} =~ ${hex_1_t} ]]
then
	pcr_ext_a=$((0x100 + ${hex_prefix}${pcr_ext_8bit_a}))
else
	pcr_ext_a=$((${hex_prefix}${pcr_ext_8bit_a}))
fi
shopt -u nocasematch

pcr_27MHz_a=$((300 * ${pcr_base_a} + ${pcr_ext_a}))


if ((8 <= ${hex_prefix}${pcr_base_lastbit_b}))
then
	pcr_base_b=$((${hex_prefix}${pcr_base_32bit_b} * 2 + 1))
else
	pcr_base_b=$((${hex_prefix}${pcr_base_32bit_b} * 2))
fi

shopt -s nocasematch
if [[ ${pcr_ext_firstbit_b} =~ ${hex_1_t} ]]
then
	pcr_ext_b=$((0x100 + ${hex_prefix}${pcr_ext_8bit_b}))
else
	pcr_ext_b=$((${hex_prefix}${pcr_ext_8bit_b}))
fi
shopt -u nocasematch

pcr_27MHz_b=$((300 * ${pcr_base_b} + ${pcr_ext_b}))


max_pcr_27MHz="300 * 2^33 + 2^9"

if ((${pcr_27MHz_b} < ${pcr_27MHz_a}))
then #account for 1 wraparound of PCR (assumption invalid if your ts is over 26h long)
	pcr_delta=$(echo "${max_pcr_27MHz} - ${pcr_27MHz_a} + ${pcr_27MHz_b}" | bc)
#some loss of precision if we hardcode 2.5769804E+12
#at least 21888.0000000 = echo "2.5769804*10^12 - (300 * 2^33 + 2^9)" | bc
elif ((${pcr_27MHz_a} == ${pcr_27MHz_b}))
then 
	pcr_delta=$(echo "${max_pcr_27MHz}" | bc)
else
	pcr_delta=$((${pcr_27MHz_b} - ${pcr_27MHz_a}))
fi


#echo "${pcr_delta}"

packet_delta=$((${packet_b} - ${packet_a}))
#echo "${packet_delta}"

Mbit_delta=$(echo "${packet_delta} * 8 * 188 / 1000000" | bc -l)
#echo "${Mbit_delta}"

avg_bitrate=$(echo "${Mbit_delta} / ${pcr_delta} * 27000000" | bc -l)
echo "${avg_bitrate}"
