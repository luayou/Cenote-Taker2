#!/bin/bash

cd $base_directory/$run_title
mkdir noncircular_non_viral_domain_contig_sketches
cd noncircular_contigs/


if [ -s noncircular_non_viral_domains_contigs.fna ] ; then
	grep "^>" noncircular_non_viral_domains_contigs.fna | sed 's/>//g' | while read LINE ; do
		CONTIG_NAME=$( echo $LINE | cut -f1 -d " " ) 
		grep -A1 "$LINE" noncircular_non_viral_domains_contigs.fna | sed '/--/d' > ../noncircular_non_viral_domain_contig_sketches/$CONTIG_NAME.fna ; 
	done
else
	echo "$(tput setaf 5)There are no contigs in the noncircular_non_viral_domains_contigs.fna file, exiting module $(tput sgr 0)"
fi

cd ../noncircular_non_viral_domain_contig_sketches

vd_fastas=$( ls *.fna )

echo "$(tput setaf 5) Trying to classify non-circular/non-ITR contigs without detected viral domains $(tput sgr 0)"

for vd_fa in $vd_fastas ; do

	echo "starting BLASTN of non-circular contigs with viral domain(s)"
	blastn -db /fdb/blastdb/nt -query $vd_fa -evalue 1e-50 -num_threads 56 -outfmt "6 qseqid sseqid stitle pident length qlen" -qcov_hsp_perc 50 -num_alignments 3 -out ${vd_fa%.fna}.blastn.out ;
	cat ${vd_fa%.fna}.blastn.out
	if [ -s "${vd_fa%.fna}.blastn.out" ]; then
		echo ${vd_fa%.fna}.blastn.out" found"
		sed 's/ /-/g' ${vd_fa%.fna}.blastn.out | awk '{if ($4 > 90) print}' | awk '{if (($5 / $6) > 0.5) print}' > ${vd_fa%.fna}.blastn.notnew.out ;
	else
		echo ${vd_fa%.fna}.blastn.out" not found"
	fi
	if [ -s "${vd_fa%.fna}.blastn.notnew.out" ]; then
		echo "$(tput setaf 4)"$vd_fa" is not a novel species (>90% identical to sequence in nt database).$(tput sgr 0)"
		ktClassifyBLAST -o ${vd_fa%.fna}.tax_guide.blastn.tab ${vd_fa%.fna}.blastn.notnew.out
		taxid=$( tail -n1 ${vd_fa%.fna}.tax_guide.blastn.tab | cut -f2 )
		efetch -db taxonomy -id $taxid -format xml | /data/tiszamj/mike_tisza/xtract.Linux -pattern Taxon -element Lineage > ${vd_fa%.fna}.tax_guide.blastn.out
		sleep 2s
		if [ !  -z "${vd_fa%.fna}.tax_guide.blastn.out" ] ; then
			awk '{ print "; "$3 }' ${vd_fa%.fna}.blastn.notnew.out | sed 's/-/ /g; s/, complete genome//g' >> ${vd_fa%.fna}.tax_guide.blastn.out
		fi

		if grep -i -q "virus\|viridae\|virales\|Circular-genetic-element\|Circular genetic element\|plasmid" ${vd_fa%.fna}.tax_guide.blastn.out ; then
			echo $vd_fa "$(tput setaf 4) is closely related to a virus that has already been deposited in GenBank nt. $(tput sgr 0)"

		else 
			echo $vd_fa "$(tput setaf 4) is closely related to a chromosomal sequence that has already been deposited in GenBank nt. It may be an endogenous virus or transposon $(tput sgr 0)"
			cat ${vd_fa%.fna}.tax_guide.blastn.out
			cp ${vd_fa%.fna}.tax_guide.blastn.out ${vd_fa%.fna}.tax_guide.CELLULAR.out

		fi
	else
		echo "$(tput setaf 5)"$vd_fa" appears to be a novel sequence (no close (>90% nucleotide) matches to sequences in nt database).$(tput sgr 0)"
	fi

	blastx -evalue 1e-2 -outfmt "6 qseqid stitle pident evalue length" -num_threads 56 -num_alignments 1 -db /data/tiszamj/mike_tisza/auto_annotation_pipeline/blast_DBs/virus_refseq_adinto_polinto_clean_plasmid_prot_190911 -query $vd_fa -out ${vd_fa%.fna}.tax_guide.blastx.out ;
	if [ ! -s "${vd_fa%.fna}.tax_guide.blastx.out" ]; then
		echo "No homologues found" > ${vd_fa%.fna}.tax_guide.blastx.out ;
	elif grep -q "adinto" ${vd_fa%.fna}.tax_guide.blastx.out ; then
		echo "Adintovirus" >> ${vd_fa%.fna}.tax_guide.blastx.out
	else
		echo "$(tput setaf 5)"$vd_fa" likely represents a novel virus or plasmid. Getting hierarchical taxonomy info.$(tput sgr 0)"
		ktClassifyBLAST -o ${vd_fa%.fna}.tax_guide.blastx.tab ${vd_fa%.fna}.tax_guide.blastx.out
		taxid=$( tail -n1 ${vd_fa%.fna}.tax_guide.blastx.tab | cut -f2 )
		efetch -db taxonomy -id $taxid -format xml | /data/tiszamj/mike_tisza/xtract.Linux -pattern Taxon -element Lineage >> ${vd_fa%.fna}.tax_guide.blastx.out
	fi
done

echo "$(tput setaf 5) HMMSCAN, expanded viral DB, non-circular/non-ITR contigs without detected viral domains $(tput sgr 0)"

for NO_END in $vd_fastas ; do
	if grep -q "Inovir" ${NO_END%.fna}.tax_guide.blastx.out ; then
		/data/tiszamj/mike_tisza/EMBOSS-6.6.0/emboss/getorf -circular -find 1 -table 11 -minsize 90 -sequence $NO_END -outseq ${NO_END%.fna}.AA.fasta ;
	elif grep -i -q "Caudovir\|Ackermannvir\|Herellevir\|Corticovir\|Levivir\|Tectivir\|crAss-like virus\|CrAssphage\|Cyanophage\|Microvir\microphage\|Siphoviridae\|Myoviridae\|phage\|Podovir\|Halovir\|sphaerolipovir\|pleolipovir\|plasmid\|Inovir\|Ampullavir\|Bicaudavir\|Fusellovir\|Guttavir\|Ligamenvir\|Plasmavir\|Salterprovir\|Cystovir" ${NO_END%.fna}.tax_guide.blastx.out ; then

		/data/tiszamj/mike_tisza/PHANOTATE/phanotate.py -f fasta -o ${NO_END%.fna}.phan.fasta $NO_END ; 
		/data/tiszamj/mike_tisza/EMBOSS-6.6.0/emboss/transeq -frame 1 -table 11 -sequence ${NO_END%.fna}.phan.fasta -outseq ${NO_END%.fna}.trans.fasta ; 
		COUNTER=0 ; 
		bioawk -c fastx '{print}' ${NO_END%.fna}.trans.fasta | while read LINE ; do 
			START_BASE=$( echo $LINE | sed 's/.*START=\(.*\)\] \[.*/\1/' ) ; 
			ORF_NAME=$( echo $LINE | cut -d " " -f1 | sed 's/\(.*\)\.[0-9].*_1/\1/' ) ; 
			END_BASE=$( echo $LINE | cut -d " " -f1 | sed 's/.*\(\.[0-9].*_1\)/\1/' | sed 's/_1//g; s/\.//g' ) ; 
			ORIG_CONTIG=$( grep ">" $NO_END | cut -d " " -f2 ) ; 
			AA_SEQ=$( echo "$LINE" | cut -f2 | sed 's/\*//g' ) ; 
			let COUNTER=COUNTER+1 ; 
			echo ">"${ORF_NAME}"_"${COUNTER} "["$START_BASE" - "$END_BASE"]" $ORIG_CONTIG ; echo $AA_SEQ ; 
		done > ${NO_END%.fna}.AA.fasta
	else
		/data/tiszamj/mike_tisza/EMBOSS-6.6.0/emboss/getorf -circular -find 1 -minsize 150 -sequence $NO_END -outseq ${NO_END%.fna}.AA.fasta ;
	fi
	hmmscan --tblout ${NO_END%.fna}.AA.hmmscan2.out --cpu 24 -E 1e-6 /data/tiszamj/mike_tisza/auto_annotation_pipeline/refseq_viral_family_proteins/useful_hmms_list3/viral_domains_total_edited2 ${NO_END%.fna}.AA.fasta
	grep -v "^#" ${NO_END%.fna}.AA.hmmscan2.out | sed 's/ \+/	/g' | sort -u -k3,3 > ${NO_END%.fna}.AA.hmmscan2.sort.out
		echo $NO_END "contains at least one viral or plasmid domain"
	if [ ! -z "${NO_END%.fna}.AA.hmmscan2.sort.out" ] ; then
		cut -f3 ${NO_END%.fna}.AA.hmmscan2.sort.out | awk '{ print $0" " }' > ${NO_END%.fna}.rotate.AA.called_hmmscan2.txt ; 

		grep -v -f ${NO_END%.fna}.rotate.AA.called_hmmscan2.txt ${NO_END%.fna}.AA.fasta | grep -A1 ">" | sed '/--/d' > ${NO_END%.fna}.no_hmmscan2.fasta
		cat ${NO_END%.fna}.rotate.AA.called_hmmscan2.txt | while read LINE ; do 
			PROTEIN_INFO=$( grep "$LINE \[" ${NO_END%.fna}.AA.fasta ) ;  
			START_BASEH=$( echo $PROTEIN_INFO | sed 's/.*\[\(.*\) -.*/\1/' ) ; 
			END_BASEH=$( echo $PROTEIN_INFO | sed 's/.*- \(.*\)\].*/\1/' ) ; 
			HMM_INFO=$( grep "$LINE " ${NO_END%.fna}.AA.hmmscan2.out | head -n1 | cut -d " " -f1 | sed 's/-/ /g; s/.*[0-9]\+\///g' ) ; 
			INFERENCEH=$( echo $HMM_INFO | cut -d " " -f1 ) ; 
			PROTEIN_NAME=$( echo $HMM_INFO | cut -d " " -f2- ) ; 
			echo -e "$START_BASEH\t""$END_BASEH\t""CDS\n""\t\t\tprotein_id\t""lcl|""$LINE\n""\t\t\tproduct\t""$PROTEIN_NAME\n""\t\t\tinference\t""similar to AA sequence:$INFERENCEH" >> ${NO_END%.fna}.SCAN.tbl ;
		done
	else
		cp ${NO_END%.fna}.AA.fasta ${NO_END%.fna}.no_hmmscan2.fasta
	fi
done

for vd_fa in $vd_fastas ; do
	if [ -s "${vd_fa%.fna}.no_hmmscan2.fasta" ]; then

		echo "$(tput setaf 5)"$vd_fa" Continuing to RPS-BLAST NCBI CDD domains database for each ORF...$(tput sgr 0)" 
		rpsblast -evalue 1e-4 -num_descriptions 5 -num_threads 56 -line_length 100 -num_alignments 1 -db /data/tiszamj/mike_tisza/auto_annotation_pipeline/cdd_rps_db/Cdd -query ${vd_fa%.fna}.no_hmmscan2.fasta -out ${vd_fa%.fna}.rotate.AA.rpsblast.out ;
		echo "$(tput setaf 5)RPS-BLAST of "${vd_fa%.fna}.no_hmmscan2.fasta" complete.$(tput sgr 0)"
		echo " "
	else
		echo "$(tput setaf 4) no ORFs for CD-HIT from "$vd_fa". all ORFs may have been called with HMMSCAN.$(tput sgr 0)"
		echo " "
	fi
done
perl /data/tiszamj/mike_tisza/auto_annotation_pipeline/rpsblastreport2tbl_mt_annotation_pipe_biowulf.pl ;
for vd_fa in $vd_fastas ; do
if [ -s "${vd_fa%.fna}.NT.tbl" ]; then
	echo "$(tput setaf 5)"$vd_fa" tbl made from RPS-BLAST hits...$(tput sgr 0)"
else
	echo "$(tput setaf 4) RPS-BLAST tbl for "$vd_fa" not detected.$(tput sgr 0)"
fi
done

echo "$(tput setaf 5) BLASTP Genbank nr non-circular/non-ITR contigs without viral domains $(tput sgr 0)"

for feat_tbl1 in *.NT.tbl ; do
	grep -i -e 'hypothetical protein' -e 'unnamed protein product' -e 'predicted protein' -e 'Uncharacterized protein' -e 'Domain of unknown function' -e 'product	gp' -B2 $feat_tbl1 | grep "^[0-9]" | awk '{print $1 " - " $2}' > ${feat_tbl1%.NT.tbl}.for_blastp.txt ;
	grep -f ${feat_tbl1%.NT.tbl}.for_blastp.txt -A1 ${feat_tbl1%.NT.tbl}.no_hmmscan2.fasta | sed '/--/d' > ${feat_tbl1%.NT.tbl}.rps_nohits.fasta ;
	if [ -s "${feat_tbl1%.NT.tbl}.rps_nohits.fasta" ]; then
		echo "$(tput setaf 5) BLASTP Genbank nr remaining ORFs of "${feat_tbl1%.NT.tbl}" $(tput sgr 0)"

			blastp -evalue 1e-4 -num_descriptions 5 -num_threads 56 -num_alignments 1 -db /fdb/blastdb/viral -query ${feat_tbl1%.NT.tbl}.rps_nohits.fasta -out ${feat_tbl1%.NT.tbl}.rotate.blastp.out ;
			echo "$(tput setaf 5)BLASTP of "${feat_tbl1%.NT.tbl}.rps_nohits.fasta" complete.$(tput sgr 0)"
	fi
done

perl /data/tiszamj/mike_tisza/auto_annotation_pipeline/blastpreport2tbl_mt_annotation_pipe_biowulf2.pl ;
for feat_tbl1 in *.NT.tbl ; do
if [ -s "${feat_tbl1%.NT.tbl}.BLASTP.tbl" ]; then
	echo "$(tput setaf 5)"${feat_tbl1%.NT.tbl}": tbl made from BLASTP hits. Splitting fasta files for HHsearch...$(tput sgr 0)"
else
	echo "$(tput setaf 4) BLASTP tbl for "${feat_tbl1%.NT.tbl}" not detected.$(tput sgr 0)"
fi
done

echo "$(tput setaf 5) Looking for tRNAs in contigs; non-circular/non-ITR contigs without viral domains  $(tput sgr 0)"

for GENOME_NAME in $vd_fastas ; do
	tRNAscan-SE -Q -G -o $GENOME_NAME.trnascan-se2.txt $GENOME_NAME
	
	if grep -q "${GENOME_NAME%.fna}" $GENOME_NAME.trnascan-se2.txt ;then

		grep "${GENOME_NAME%.fna}" $GENOME_NAME.trnascan-se2.txt | while read LINE ; do 
			TRNA_START=$( echo $LINE | cut -d " " -f3 ) ; 
			TRNA_END=$( echo $LINE | cut -d " " -f4 ) ; 
			TRNA_NUMBER=$( echo $LINE | cut -d " " -f2 ) ; 
			TRNA_TYPE=$( echo $LINE | cut -d " " -f5 ) ; 
			TRNA_SCORE=$( echo $LINE | cut -d " " -f9 ) ; 
			echo -e "$TRNA_START\t""$TRNA_END\t""tRNA\n""\t\t\tgene\t""$GENOME_NAME""_tRNA$TRNA_NUMBER\n""\t\t\tproduct\t""tRNA-$TRNA_TYPE\n""\t\t\tinference\t""tRNAscan-SE score:$TRNA_SCORE" >> ${GENOME_NAME%.fna}.trna.tbl; 
		done
	fi
done

echo "$(tput setaf 5) combining intermediate .tbl files; non-circular/non-ITR contigs without viral domains  $(tput sgr 0)"

for nucl_fa in $vd_fastas ; do
	if [ -s ${nucl_fa%.fna}.NT.tbl ] && [ -s ${nucl_fa%.fna}.SCAN.tbl ] && [ -s ${nucl_fa%.fna}.BLASTP.tbl ] ; then
		cat ${nucl_fa%.fna}.BLASTP.tbl > ${nucl_fa%.fna}.int.tbl
		echo -e "\n" >> ${nucl_fa%.fna}.int.tbl
		grep -v -e 'hypothetical protein' -e 'unnamed protein product' -e 'Predicted protein' -e 'predicted protein' -e 'Uncharacterized protein' -e 'Domain of unknown function' -e 'product	gp' ${nucl_fa%.fna}.NT.tbl | grep -A1 -B2 'product' | grep -v ">Feature" | sed '/--/d' >> ${nucl_fa%.fna}.int.tbl ;
		echo -e "\n" >> ${nucl_fa%.fna}.int.tbl
		cat ${nucl_fa%.fna}.SCAN.tbl | grep -v ">Feature" >> ${nucl_fa%.fna}.int.tbl
		if [ -s ${nucl_fa%.fna}.trna.tbl ] ; then
			echo -e "\n" >> ${nucl_fa%.fna}.int.tbl
			cat ${nucl_fa%.fna}.trna.tbl >> ${nucl_fa%.fna}.int.tbl
		fi
	elif [ -s ${nucl_fa%.fna}.SCAN.tbl ] && [ -s ${nucl_fa%.fna}.BLASTP.tbl ] ; then
		cat ${nucl_fa%.fna}.BLASTP.tbl > ${nucl_fa%.fna}.int.tbl
		echo -e "\n" >> ${nucl_fa%.fna}.int.tbl
		cat ${nucl_fa%.fna}.SCAN.tbl | grep -v ">Feature" >> ${nucl_fa%.fna}.int.tbl
		if [ -s ${nucl_fa%.fna}.trna.tbl ] ; then
			echo -e "\n" >> ${nucl_fa%.fna}.int.tbl
			cat ${nucl_fa%.fna}.trna.tbl >> ${nucl_fa%.fna}.int.tbl
		fi
	elif [ -s ${nucl_fa%.fna}.NT.tbl ] && [ -s ${nucl_fa%.fna}.BLASTP.tbl ] ; then
		cat ${nucl_fa%.fna}.BLASTP.tbl > ${nucl_fa%.fna}.int.tbl
		echo -e "\n" >> ${nucl_fa%.fna}.int.tbl
		grep -v -e 'hypothetical protein' -e 'unnamed protein product' -e 'Predicted protein' -e 'predicted protein' -e 'Uncharacterized protein' -e 'Domain of unknown function' -e 'product	gp' ${nucl_fa%.fna}.NT.tbl | grep -A1 -B2 'product' | grep -v ">Feature" | sed '/--/d' >> ${nucl_fa%.fna}.int.tbl ;
		if [ -s ${nucl_fa%.fna}.trna.tbl ] ; then
			echo -e "\n" >> ${nucl_fa%.fna}.int.tbl
			cat ${nucl_fa%.fna}.trna.tbl >> ${nucl_fa%.fna}.int.tbl
		fi
	elif [ -s ${nucl_fa%.fna}.NT.tbl ] ; then
		cat ${nucl_fa%.fna}.NT.tbl > ${nucl_fa%.fna}.int.tbl
		if [ -s ${nucl_fa%.fna}.trna.tbl ] ; then
			echo -e "\n" >> ${nucl_fa%.fna}.int.tbl
			cat ${nucl_fa%.fna}.trna.tbl >> ${nucl_fa%.fna}.int.tbl
		fi
	elif [ -s ${nucl_fa%.fna}.SCAN.tbl ] ; then
		cat ${nucl_fa%.fna}.SCAN.tbl > ${nucl_fa%.fna}.int.tbl
		if [ -s ${nucl_fa%.fna}.trna.tbl ] ; then
			echo -e "\n" >> ${nucl_fa%.fna}.int.tbl
			cat ${nucl_fa%.fna}.trna.tbl >> ${nucl_fa%.fna}.int.tbl
		fi
	elif [ -s ${nucl_fa%.fna}.BLASTP.tbl ] ; then
		cat ${nucl_fa%.fna}.BLASTP.tbl > ${nucl_fa%.fna}.int.tbl
		if [ -s ${nucl_fa%.fna}.trna.tbl ] ; then
			echo -e "\n" >> ${nucl_fa%.fna}.int.tbl
			cat ${nucl_fa%.fna}.trna.tbl >> ${nucl_fa%.fna}.int.tbl
		fi
	fi
done

echo "$(tput setaf 5) Removing 'hypothetical' ORFs-within-ORFs; non-circular/non-ITR contigs without viral domains  $(tput sgr 0)"

for feat_tbl3 in *.int.tbl ; do
	grep "^[0-9]" $feat_tbl3 | awk '{FS="\t"; OFS="\t"} {print $1, $2}' > ${feat_tbl3%.int.tbl}.all_start_stop.txt ;
	cat "${feat_tbl3%.int.tbl}.all_start_stop.txt" | while read linev ; do
		all_start=$( echo $linev | cut -d " " -f1 )
		all_end=$( echo $linev | cut -d " " -f2 )
		if [[ "$all_end" -gt "$all_start" ]]; then
			for ((counter_f=(( $all_start + 1 ));counter_f<=$all_end;counter_f++)); do
				echo " " "$counter_f" " " >> ${feat_tbl3%.int.tbl}.used_positions.txt
				
			done
		elif [[ "$all_start" -gt "$all_end" ]]; then
			for ((counter_r=$all_end;counter_r<=(( $all_start - 1 ));counter_r++)) ; do
				echo " " "$counter_r" " " >> ${feat_tbl3%.int.tbl}.used_positions.txt
			done
		fi
	done
	sed 's/(Fragment)//g; s/\. .*//g; s/{.*//g; s/\[.*//g; s/Putative hypothetical protein/hypothetical protein/g; s/Uncultured bacteri.*/hypothetical protein/g; s/RNA helicase$/helicase/g; s/Os.*/hypothetical protein/g; s/\.$//g; s/Unplaced genomic scaffold.*/hypothetical protein/g; s/Putative hypothetical protein/hypothetical protein/g; s/Contig.*/hypothetical protein/g; s/Uncharacterized protein/hypothetical protein/g; s/uncharacterized protein/hypothetical protein/g; s/Uncharacterised protein/hypothetical protein/g' $feat_tbl3 | sed '/--/d' > ${feat_tbl3%.int.tbl}.comb2.tbl ; 
	grep -e 'hypothetical protein' -B2 ${feat_tbl3%.int.tbl}.comb2.tbl | grep "^[0-9]" | awk '{FS="\t"; OFS="\t"} {print $1, $2}' > ${feat_tbl3%.int.tbl}.hypo_start_stop.txt ;

	cat "${feat_tbl3%.int.tbl}.hypo_start_stop.txt" | while read liney ; do
		loc_start=$( echo $liney | cut -d " " -f1 )
		loc_end=$( echo $liney | cut -d " " -f2 )
		loc1_start=$( echo " " "$loc_start" " " )
		if grep -q "$loc1_start" ${feat_tbl3%.int.tbl}.used_positions.txt ; then 
			echo $feat_tbl3
			echo "$loc1_start"
			if [[ "$loc_end" -gt "$loc_start" ]]; then
				gen_len=$(( $loc_end - $loc_start ))

				if [[ "$gen_len" -gt 1000 ]]; then
					continue
				else
					f_end=$(( $loc_end + 1 ))
					f1_end=$( echo " " "$f_end" " ")
					echo "$f1_end"
					if grep -q "$f1_end" ${feat_tbl3%.int.tbl}.used_positions.txt ; then
						echo "removing hypo"
						echo "$loc1_start" "start, " "$loc_end" "end, " 
						echo "$liney" >> ${feat_tbl3%.int.tbl}.remove_hypo.txt
					fi
				fi
			else
				gen_len=$(( $loc_start - $loc_end ))

				if [[ "$gen_len" -gt 1000 ]]; then
					continue
				else
				r_end=$(( $loc_end - 1 ))
				r1_end=$( echo " " "$r_end" " ")

				echo "$r1_end"
					if grep -q "$r1_end" ${feat_tbl3%.int.tbl}.used_positions.txt ; then
							echo "removing hypo"
							echo "$loc1_start" "start, " "$loc_end" "end, " 
							echo "$liney" >> ${feat_tbl3%.int.tbl}.remove_hypo.txt
					fi
				fi
			fi
		fi
	done
	if [ -s "${feat_tbl3%.int.tbl}.remove_hypo.txt" ]; then
		grep ">Feature" ${feat_tbl3%.int.tbl}.comb2.tbl | sed '/--/d' > ${feat_tbl3%.int.tbl}.int2.tbl
		grep -v -f ${feat_tbl3%.int.tbl}.remove_hypo.txt ${feat_tbl3%.int.tbl}.comb2.tbl | grep "^[0-9]" -A3 | sed '/--/d' >> ${feat_tbl3%.int.tbl}.int2.tbl ;
		else
			cp ${feat_tbl3%.int.tbl}.comb2.tbl ${feat_tbl3%.int.tbl}.int2.tbl
	fi
done

echo "$(tput setaf 5) Parsing ORFs for HHsearch ; non-circular/non-ITR contigs without viral domains  $(tput sgr 0)"

for blastp_tbl1 in *.int2.tbl ; do
grep -i -e 'hypothetical protein' -e 'unnamed protein product' -e 'predicted protein' -e 'Uncharacterized protein' -e 'Uncharacterized conserved protein' -e 'unknown' -e 'Uncharacterised protein' -e 'product	gp' -B2 $blastp_tbl1 | grep "^[0-9]" | awk '{print $1 " - " $2}' > ${blastp_tbl1%.int2.tbl}.for_hhpred.txt ;
grep -f ${blastp_tbl1%.int2.tbl}.for_hhpred.txt -A1 ${blastp_tbl1%.int2.tbl}.rps_nohits.fasta | sed '/--/d' > ${blastp_tbl1%.int2.tbl}.blast_hypo.fasta ;
csplit -z ${blastp_tbl1%.int2.tbl}.blast_hypo.fasta '/>/' '{*}' --prefix=${blastp_tbl1%.int2.tbl}. --suffix-format=%02d.for_hhpred.fasta; 
done

dark_orf_list=$( ls *.for_hhpred.fasta )
echo "$(tput setaf 5) Conducting HHsearch on remaining ORFs; non-circular/non-ITR contigs without viral domains  $(tput sgr 0)"

for dark_orf in $dark_orf_list ; do
	if  [[ $HHSUITE_TOOL = "-hhsearch" ]] ; then

		echo "$(tput setaf 5)Running HHsearch on "$dark_orf" now.$(tput sgr 0)"
		hhsearch -i $dark_orf -d /data/tiszamj/mike_tisza/auto_annotation_pipeline/pdb70/pdb70 -d /data/tiszamj/mike_tisza/auto_annotation_pipeline/pfam_31_db/pfam -d /data/tiszamj/mike_tisza/auto_annotation_pipeline/cdd_db/NCBI_CD/NCBI_CD -o ${dark_orf%.for_hhpred.fasta}.out.hhr -cpu 56 -maxmem 56 -p 80 -Z 20 -z 0 -b 0 -B 10 -ssm 2 -sc 1  ;
		cat ${dark_orf%.for_hhpred.fasta}.out.hhr >> ${dark_orf%.rotate*.for_hhpred.fasta}.rotate.out_all.hhr ;
		rm ${dark_orf%.for_hhpred.fasta}.out.hhr 
		cat $dark_orf >> ${dark_orf%.rotate*.for_hhpred.fasta}.all_hhpred_queries.AA.fasta
		rm $dark_orf
	elif [[ $HHSUITE_TOOL = "-hhblits" ]] ; then
		echo "$(tput setaf 5)Running HHblits on "$dark_orf" now.$(tput sgr 0)"
		hhblits -i $dark_orf -d /data/tiszamj/mike_tisza/auto_annotation_pipeline/pdb70/pdb70 -d /data/tiszamj/mike_tisza/auto_annotation_pipeline/pfam_31_db/pfam -d /data/tiszamj/mike_tisza/auto_annotation_pipeline/cdd_db/NCBI_CD/NCBI_CD -o ${dark_orf%.for_hhpred.fasta}.out.hhr -cpu 56 -maxmem 56 -p 80 -Z 20 -z 0 -b 0 -B 10 -ssm 2 -sc 1  ;
		cat ${dark_orf%.for_hhpred.fasta}.out.hhr >> ${dark_orf%.rotate*.for_hhpred.fasta}.rotate.out_all.hhr ;
		rm ${dark_orf%.for_hhpred.fasta}.out.hhr 
		cat $dark_orf >> ${dark_orf%.rotate*.for_hhpred.fasta}.all_hhpred_queries.AA.fasta
		rm $dark_orf
	else
		echo "$(tput setaf 5) Valid option for HHsuite tool (i.e. -hhsearch or -hhblits) was not provided. Skipping step for "$dark_orf" $(tput sgr 0)"
		cat $dark_orf >> ${dark_orf%.rotate*.for_hhpred.fasta}.all_hhpred_queries.AA.fasta
		rm $dark_orf
	fi
done

rm *.out.hhr

# Generating tbl file from HHpred results
perl /data/tiszamj/mike_tisza/auto_annotation_pipeline/hhpredreport2tbl_mt_annotation_pipe_biowulf1_gjs_edits.pl ;

for HH_tbl1 in *.HH.tbl ; do 
sed 's/OS=.*//g; s/ ;//g; s/UniProtKB:>\([0-9][A-Z].*\)/PDB:\1/g; s/UniProtKB:>tr|.*|\(.\)/UniProtKB:\1/g; s/UniProtKB:>\([a-z].*\)/Scop:\1/g; s/UniProtKB:>\(PF.*\)/PFAM:\1/g; s/ is .*//g; s/ are .*//g' $HH_tbl1 > ${HH_tbl1%.HH.tbl}.HH2.tbl
done


for feat_tbl4 in *.int2.tbl ; do 
	if [ -s "${feat_tbl4%.int2.tbl}.HH2.tbl" ] && [ -s "$feat_tbl4" ] ; then
		head -n1 $feat_tbl4 > ${feat_tbl4%.int2.tbl}.comb3.tbl
		grep -v -e 'hypothetical protein' -e 'unnamed protein product' -e 'unknown' -e 'Predicted protein' -e 'predicted protein' -e 'Uncharacterized protein' -e 'Domain of unknown function' -e 'product	gp' $feat_tbl4 | grep -A1 -B2 'product' | grep -v ">Feature" | sed '/--/d' >> ${feat_tbl4%.int2.tbl}.comb3.tbl
		sed 's/(Fragment)//g; s/\. .*//g; s/{.*//g; s/\[.*//g; s/Putative hypothetical protein/hypothetical protein/g; s/Uncultured bacteri.*/hypothetical protein/g; s/RNA helicase$/helicase/g; s/Os.*/hypothetical protein/g; s/\.$//g; s/Unplaced genomic scaffold.*/hypothetical protein/g; s/Putative hypothetical protein/hypothetical protein/g; s/Contig.*/hypothetical protein/g; s/Uncharacterized protein/hypothetical protein/g; s/uncharacterized protein/hypothetical protein/g; s/Uncharacterised protein/hypothetical protein/g' ${feat_tbl4%.int2.tbl}.HH2.tbl | grep -v ">Feature" | sed '/--/d' >> ${feat_tbl4%.int2.tbl}.comb3.tbl ;
	else
		cat $feat_tbl4 > ${feat_tbl4%.int2.tbl}.comb3.tbl
	fi
done


# .gff file maker
echo "$(tput setaf 5) Making GFF file of annotations; non-circular/non-ITR contigs without viral domains  $(tput sgr 0)"


for feat_tbl2 in *.comb3.tbl ; do
	if [ -s ${feat_tbl2%.comb3.tbl}.gtf ] ; then
		rm ${feat_tbl2%.comb3.tbl}.gtf
	fi
	grep "^[0-9]" -A3 $feat_tbl2 | sed '/--/d' | sed 's/ /_/g' | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n		//g' | while read LINE ; do
		if echo $LINE | grep -q "CDS" ; then
			GENOME=${feat_tbl2%.comb3.tbl}
			FEAT_TYPE=$( echo $LINE | cut -d " " -f3 )
			FEAT_START=$( echo $LINE | cut -d " " -f1 )
			FEAT_END=$( echo $LINE | cut -d " " -f2 )
			FEAT_NAME=$( echo $LINE | cut -d " " -f7 )
			FEAT_ATT=$( echo $LINE | cut -d " " -f9 )
			FEAT_ID=$( echo $LINE | cut -d " " -f5 )
		elif echo $LINE | grep -q "repeat_region" ; then
			GENOME=${feat_tbl2%.comb3.tbl}
			FEAT_TYPE=$( echo $LINE | cut -d " " -f3 )
			FEAT_START=$( echo $LINE | cut -d " " -f1 )
			FEAT_END=$( echo $LINE | cut -d " " -f2 )
			FEAT_NAME="ITR"
			FEAT_ATT="ITR"
			FEAT_ID="ITR"	
		fi


		echo -e "$GENOME\t""Cenote-Taker\t""$FEAT_TYPE\t""$FEAT_START\t""$FEAT_END\t"".\t"".\t"".\t""gene_id \"$FEAT_ID\"; gene_name \"$FEAT_NAME\"; gene_inference \"$FEAT_ATT\"" >> ${feat_tbl2%.comb3.tbl}.gtf
	done
done

cat *.gtf > all_gtfs_concat.txt
if [ ! -z all_gtfs_concat.txt ] ; then
	cat all_gtfs_concat.txt | while read LINE ; do
		CENOTE_NAME=$( echo "$LINE" | cut -f1 )
		CONTIG_NAME=$( head -n1 ${CENOTE_NAME}.fna | cut -d " " -f2 )
		echo "$LINE" | sed "s/$CENOTE_NAME/$CONTIG_NAME/g" >> file_for_assembly_graph_incompletes.gtf
	done
fi


# Making directory for sequin generation
if [ ! -d "sequin_directory" ]; then
	mkdir sequin_directory
fi


# Getting info for virus nomenclature and divergence 
echo "$(tput setaf 5) making .tbl, .cmt, and .fsa files for sequin; non-circular/non-ITR contigs with viral domains  $(tput sgr 0)"

for feat_tbl2 in *.comb3.tbl ; do 
	file_core=${feat_tbl2%.comb3.tbl}
	#echo $file_core
	file_numbers=$( echo ${file_core: -3} | sed 's/[a-z]//g' | sed 's/[A-Z]//g' )
	#echo $file_numbers
	tax_info=${feat_tbl2%.comb3.tbl}.tax_guide.blastx.out
	#echo $tax_info
	if grep -q "Anellovir" $tax_info ; then
		vir_name=Anelloviridae ;
	elif grep -q "Adenovir" $tax_info ; then
		vir_name=Adenoviridae ;
	elif grep -q "Alphasatellit" $tax_info ; then
		vir_name=Alphasatellitidae ;
	elif grep -q "Ampullavir" $tax_info ; then
		vir_name=Ampullaviridae ;
	elif grep -q "Ascovir" $tax_info ; then
		vir_name=Ascoviridae ;
	elif grep -q "Asfarvir" $tax_info ; then
		vir_name=Asfarviridae ;
	elif grep -q "Bacilladnavir" $tax_info ; then
		vir_name=Bacilladnaviridae ;
	elif grep -q "Baculovir" $tax_info ; then
		vir_name=Baculoviridae ;
	elif grep -q "Bicaudavir" $tax_info ; then
		vir_name=Bicaudaviridae ;
	elif grep -q "Bidnavir" $tax_info ; then
		vir_name=Bidnaviridae ;
	elif grep -q "Ackermannvir" $tax_info ; then
		vir_name=Ackermannviridae ;
	elif grep -q "Herellevir" $tax_info ; then
		vir_name=Herelleviridae ;
	elif grep -q "Clavavir" $tax_info ; then
		vir_name=Clavaviridae ;
	elif grep -q "Adomavir" $tax_info ; then
		vir_name=Adomaviridae ;
	elif grep -q "Corticovir" $tax_info ; then
		vir_name=Corticoviridae ;
	elif grep -q "Dinodnavir" $tax_info ; then
		vir_name=Dinodnavirus ;
	elif grep -q "Autolykivir" $tax_info ; then
		vir_name=Autolykiviridae ;
	elif grep -q "Globulovir" $tax_info ; then
		vir_name=Globuloviridae ;
	elif grep -q "Pithovir" $tax_info ; then
		vir_name=Pithoviridae ;
	elif grep -q "Pandoravir" $tax_info ; then
		vir_name=Pandoravirus ;
	elif grep -q "Fusellovir" $tax_info ; then
		vir_name=Fuselloviridae ;
	elif grep -q "Guttavir" $tax_info ; then
		vir_name=Guttaviridae ;
	elif grep -q "Hepadnavir" $tax_info ; then
		vir_name=Hepadnaviridae ;
	elif grep -q "Herpesvir" $tax_info ; then
		vir_name=Herpesvirales ;
	elif grep -q "Hytrosavir" $tax_info ; then
		vir_name=Hytrosaviridae ;
	elif grep -q "Iridovir" $tax_info ; then
		vir_name=Iridoviridae ;
	elif grep -q "Lavidavir" $tax_info ; then
		vir_name=Lavidaviridae ;
	elif grep -q "Adintovir" $tax_info ; then
		vir_name=Adintovirus ;
	elif grep -q "Lipothrixvir" $tax_info ; then
		vir_name=Lipothrixviridae ;
	elif grep -q "Rudivir" $tax_info ; then
		vir_name=Rudiviridae ;
	elif grep -q "Ligamenvir" $tax_info ; then
		vir_name=Ligamenvirales ;
	elif grep -q "Marseillevir" $tax_info ; then
		vir_name=Marseilleviridae ;
	elif grep -q "Mimivir" $tax_info ; then
		vir_name=Mimiviridae ;
	elif grep -q "Nanovir" $tax_info ; then
		vir_name=Nanoviridae ;
	elif grep -q "Nimavir" $tax_info ; then
		vir_name=Nimaviridae ;
	elif grep -q "Nudivir" $tax_info ; then
		vir_name=Nudiviridae ;
	elif grep -q "Caulimovir" $tax_info ; then
		vir_name=Caulimoviridae ;
	elif grep -q "Metavir" $tax_info ; then
		vir_name=Metaviridae ;
	elif grep -q "Pseudovir" $tax_info ; then
		vir_name=Pseudoviridae ;
	elif grep -q "Retrovir" $tax_info ; then
		vir_name=Retroviridae ;
	elif grep -q "Ovalivir" $tax_info ; then
		vir_name=Ovaliviridae ;
	elif grep -q "Parvovir" $tax_info ; then
		vir_name=Parvoviridae ;
	elif grep -q "Phycodnavir" $tax_info ; then
		vir_name=Phycodnaviridae ;
	elif grep -q "Plasmavir" $tax_info ; then
		vir_name=Plasmaviridae ;
	elif grep -q "Pleolipovir" $tax_info ; then
		vir_name=Pleolipoviridae ;
	elif grep -q "Polydnavir" $tax_info ; then
		vir_name=Polydnaviridae ;
	elif grep -q "Portoglobovir" $tax_info ; then
		vir_name=Portogloboviridae ;
	elif grep -q "Poxvir" $tax_info ; then
		vir_name=Poxviridae ;
	elif grep -q "Albetovir" $tax_info ; then
		vir_name=Albetoviridae ;
	elif grep -q "Alphatetravir" $tax_info ; then
		vir_name=Alphatetraviridae ;
	elif grep -q "Alvernavir" $tax_info ; then
		vir_name=Alvernaviridae ;
	elif grep -q "Amalgavir" $tax_info ; then
		vir_name=Amalgaviridae ;
	elif grep -q "Astrovir" $tax_info ; then
		vir_name=Astroviridae ;
	elif grep -q "Aumaivir" $tax_info ; then
		vir_name=Aumaivirus ;
	elif grep -q "Avsunviroid" $tax_info ; then
		vir_name=Avsunviroidae ;
	elif grep -q "Barnavir" $tax_info ; then
		vir_name=Barnaviridae ;
	elif grep -q "Benyvir" $tax_info ; then
		vir_name=Benyviridae ;
	elif grep -q "Birnavir" $tax_info ; then
		vir_name=Birnaviridae ;
	elif grep -q "Botourmiavir" $tax_info ; then
		vir_name=Botourmiaviridae ;
	elif grep -q "Botybirnavir" $tax_info ; then
		vir_name=Botybirnavirus ;
	elif grep -q "Bromovir" $tax_info ; then
		vir_name=Bromoviridae ;
	elif grep -q "Calicivir" $tax_info ; then
		vir_name=Caliciviridae ;
	elif grep -q "Carmotetravir" $tax_info ; then
		vir_name=Carmotetraviridae ;
	elif grep -q "Chrysovir" $tax_info ; then
		vir_name=Chrysoviridae ;
	elif grep -q "Closterovir" $tax_info ; then
		vir_name=Closteroviridae ;
	elif grep -q "Cystovir" $tax_info ; then
		vir_name=Cystoviridae ;
	elif grep -q "Deltavir" $tax_info ; then
		vir_name=Deltavirus ;
	elif grep -q "Endornavir" $tax_info ; then
		vir_name=Endornaviridae ;
	elif grep -q "Flavivir" $tax_info ; then
		vir_name=Flaviviridae ;
	elif grep -q "Hepevir" $tax_info ; then
		vir_name=Hepeviridae ;
	elif grep -q "Hypovir" $tax_info ; then
		vir_name=Hypoviridae ;
	elif grep -q "Idaeovir" $tax_info ; then
		vir_name=Idaeovirus ;
	elif grep -q "Kitavir" $tax_info ; then
		vir_name=Kitaviridae ;
	elif grep -q "Levivir" $tax_info ; then
		vir_name=Leviviridae ;
	elif grep -q "Luteovir" $tax_info ; then
		vir_name=Luteoviridae ;
	elif grep -q "Matonavir" $tax_info ; then
		vir_name=Matonaviridae ;
	elif grep -q "Megabirnavir" $tax_info ; then
		vir_name=Megabirnaviridae ;
	elif grep -q "Narnavir" $tax_info ; then
		vir_name=Narnaviridae ;
	elif grep -q "Nidovir" $tax_info ; then
		vir_name=Nidovirales ;
	elif grep -q "Nodavir" $tax_info ; then
		vir_name=Nodaviridae ;
	elif grep -q "Papanivir" $tax_info ; then
		vir_name=Papanivirus ;
	elif grep -q "Partitivir" $tax_info ; then
		vir_name=Partitiviridae ;
	elif grep -q "Permutotetravir" $tax_info ; then
		vir_name=Permutotetraviridae ;
	elif grep -q "Picobirnavir" $tax_info ; then
		vir_name=Picobirnaviridae ;
	elif grep -q "Dicistrovir" $tax_info ; then
		vir_name=Dicistroviridae ;
	elif grep -q "Iflavir" $tax_info ; then
		vir_name=Iflaviridae ;
	elif grep -q "Marnavir" $tax_info ; then
		vir_name=Marnaviridae ;
	elif grep -q "Picornavir" $tax_info ; then
		vir_name=Picornaviridae ;
	elif grep -q "Polycipivir" $tax_info ; then
		vir_name=Polycipiviridae ;
	elif grep -q "Secovir" $tax_info ; then
		vir_name=Secoviridae ;
	elif grep -q "Picornavir" $tax_info ; then
		vir_name=Picornavirales ;
	elif grep -q "Pospiviroid" $tax_info ; then
		vir_name=Pospiviroidae ;
	elif grep -q "Potyvir" $tax_info ; then
		vir_name=Potyviridae ;
	elif grep -q "Quadrivir" $tax_info ; then
		vir_name=Quadriviridae ;
	elif grep -q "Reovir" $tax_info ; then
		vir_name=Reoviridae ;
	elif grep -q "Sarthrovir" $tax_info ; then
		vir_name=Sarthroviridae ;
	elif grep -q "Sinaivir" $tax_info ; then
		vir_name=Sinaivirus ;
	elif grep -q "Solemovir" $tax_info ; then
		vir_name=Solemoviridae ;
	elif grep -q "Solinvivir" $tax_info ; then
		vir_name=Solinviviridae ;
	elif grep -q "Togavir" $tax_info ; then
		vir_name=Togaviridae ;
	elif grep -q "Tombusvir" $tax_info ; then
		vir_name=Tombusviridae ;
	elif grep -q "Totivir" $tax_info ; then
		vir_name=Totiviridae ;
	elif grep -q "Tymovir" $tax_info ; then
		vir_name=Tymovirales ;
	elif grep -q "Virgavir" $tax_info ; then
		vir_name=Virgaviridae ;
	elif grep -q "Virtovir" $tax_info ; then
		vir_name=Virtovirus ;
	elif grep -q "Salterprovir" $tax_info ; then
		vir_name=Salterprovirus ;
	elif grep -q "Smacovir" $tax_info ; then
		vir_name=Smacoviridae ;
	elif grep -q "Sphaerolipovir" $tax_info ; then
		vir_name=Sphaerolipoviridae ;
	elif grep -q "Spiravir" $tax_info ; then
		vir_name=Spiraviridae ;
	elif grep -q "Crucivir" $tax_info ; then
		vir_name=Cruciviridae ;
	elif grep -q "Tectivir" $tax_info ; then
		vir_name=Tectiviridae ;
	elif grep -q "Tolecusatellit" $tax_info ; then
		vir_name=Tolecusatellitidae ;
	elif grep -q "Tristromavir" $tax_info ; then
		vir_name=Tristromaviridae ;
	elif grep -q "Turrivir" $tax_info ; then
		vir_name=Turriviridae ;
	elif grep -q "crAss-like virus\|CrAssphage" $tax_info ; then
		vir_name="CrAss-like virus" ;
	elif grep -q "Cyanophage" $tax_info ; then
		vir_name=Cyanophage ;
	elif grep -q "Mavir\|virophage" $tax_info ; then
		vir_name=Virophage ;
	elif grep -q "Microvir" $tax_info ; then
		vir_name=Microviridae ;
	elif grep -q "microphage" $tax_info ; then
		vir_name=Microviridae ;
	elif grep -q "uncultured marine virus" $tax_info ; then
		vir_name="Virus" ;
	elif grep -q "Inovir" $tax_info ; then
		vir_name=Inoviridae ;
	elif grep -q "Siphovir" $tax_info ; then
		vir_name=Siphoviridae ;
	elif grep -q "Myovir" $tax_info ; then
		vir_name=Myoviridae ;		
	elif grep -q "unclassified dsDNA phage" $tax_info ; then
		vir_name="Phage" ;
	elif grep -q "unclassified ssDNA virus" $tax_info ; then
		vir_name="CRESS virus" ;
	elif grep -q "Lake Sarah" $tax_info ; then
		vir_name="CRESS virus" ;
	elif grep -q "Avon-Heathcote" $tax_info ; then
		vir_name="CRESS virus" ;
	elif grep -q "Circovir" $tax_info ; then
		vir_name=Circoviridae ;
	elif grep -q "Genomovir" $tax_info ; then
		vir_name=Genomoviridae ;
	elif grep -q "Geminivir" $tax_info ; then
		vir_name=Geminiviridae ;
	elif grep -q "Polyoma" $tax_info ; then
		vir_name=Polyomaviridae ;
	elif grep -q "Papillomavir" $tax_info ; then
		vir_name=Papillomaviridae ;
	elif grep -q "Halovir" $tax_info ; then
		vir_name=Halovirus ;
	elif grep -q "No homologues found" $tax_info ; then
		if  [[ $1 = "-given_linear" ]]; then
			vir_name="genetic element" ;
		else
			vir_name="circular genetic element" ;
		fi
	elif grep -q "Circular genetic element" $tax_info ; then
		vir_name="Circular genetic element" ;
	elif grep -q "Podovir" $tax_info ; then
		vir_name=Podoviridae ;
	elif grep -q "Caudovir" $tax_info ; then
		vir_name=Caudovirales ;
	elif grep -q "dsRNA virus" $tax_info ; then
		vir_name="dsRNA virus" ;
	elif grep -q "ssRNA virus" $tax_info ; then
		vir_name="ssRNA virus" ;
	elif grep -q "unclassified RNA virus" $tax_info ; then
		vir_name="unclassified RNA virus" ;
	elif grep -q "Satellite" $tax_info ; then
		vir_name="Satellite virus" ;
	elif grep -q "unclassified ssDNA bacterial virus" $tax_info ; then
		vir_name="unclassified ssDNA bacterial virus" ;
	elif grep -q "phage" $tax_info ; then
		vir_name="Phage" ;
	elif grep -q "plasmid" $tax_info ; then
		vir_name="metagenomic plasmid" ;
	elif grep -q "Bacteria" $tax_info ; then
		vir_name="Phage" ;
	elif grep -q "virus" $tax_info ; then
		vir_name="Virus" ;
	else
		if  [[ $1 = "-given_linear" ]]; then
			vir_name="unclassified element" ;
		else
			vir_name="Circular genetic element" ;
		fi
	fi
	echo $vir_name ;
#	feature_head=$( echo ">Feature" $3"-associated" $vir_name $file_numbers" Table1" )
	fsa_head=$( echo $vir_name " sp." )
	tax_guess=$( tail -n1 ${feat_tbl2%.comb3.tbl}.tax_guide.blastx.out ) ; 
	perc_id=$( head -n1 ${feat_tbl2%.comb3.tbl}.tax_guide.blastx.out | sed 's/ /-/g' | awk '{FS="\t"; OFS="\t"} {print $2" "$3}' | sed 's/-/ /g' ) ;
	rand_id=$( echo $RANDOM | tr '[0-9]' '[a-zA-Z]' | cut -c 1-2 )
	seq_name1=$( head -n1 ${feat_tbl2%.comb3.tbl}.fna | sed 's/>//g; s/|.*//g' | cut -d " " -f2 )

# Editing and transferring tbl file and fasta (fsa) files to sequin directory
	echo "$(tput setaf 5) Editing and transferring tbl file and fasta (fsa) files to sequin directory $(tput sgr 0)"

	if [ -s ${feat_tbl2%.comb3.tbl}.phan.fasta ]; then
		echo "$(tput setaf 5)tbl file made from: "$feat_tbl2" (viral-domain-containing contig) will be used for sqn generation$(tput sgr 0)" ; 
		cp $feat_tbl2 sequin_directory/${feat_tbl2%.comb3.tbl}.tbl ; 
		if [ -s ${feat_tbl2%.comb3.tbl}.tax_guide.CELLULAR.out ] ; then
			CELL_CHROM=$( cat ${feat_tbl2%.comb3.tbl}.blastn.notnew.out | head -n1 | cut -f3 )
			bioawk -v contig_name="$seq_name1" -v srr_var="$srr_number" -v tax_var="$tax_guess" -v perc_var="$perc_id" -v headername="$fsa_head" -v newname="$file_core" -v source_var="$isolation_source" -v rand_var="$rand_id" -v number_var="$file_numbers" -v date_var="$collection_date" -v metgenome_type_var="$metagenome_type" -v srx_var="$srx_number" -v prjn_var="$bioproject" -v samn_var="$biosample" -v chrom_info="$CELL_CHROM" -v molecule_var="$MOLECULE_TYPE" -c fastx '{ print ">" newname " [note=highly similar to sequence "chrom_info " ; please manually check if this is a transposon especially if there is an annotated reverse transcriptase ] [note= "contig_name" ; closest viral relative: " tax_var " " perc_var "] [organism=" headername " ct" rand_var number_var "; WARNING: no viral/plasmid-specific domains were detected. This is probably not a true mobile genetic element.] [moltype=genomic "molecule_var"][isolation_source=" source_var "] [isolate=ct" rand_var number_var " ] [country=USA] [collection_date=" date_var "] [metagenome_source=" metgenome_type_var "] [note=genome binned from sequencing reads available in " srx_var "] [topology=linear] [Bioproject=" prjn_var "] [Biosample=" samn_var "] [SRA=" srr_var "] [gcode=11]" ; print $seq }' ${feat_tbl2%.comb3.tbl}.fna > sequin_directory/${feat_tbl2%.comb3.tbl}.fsa ;	
			echo "$(tput setaf 3) WARNING: no viral/plasmid-specific domains were detected in "${feat_tbl2%.comb3.tbl}". This is probably not a true mobile genetic element. Scrutinize carefully. $(tput sgr 0)"

		else
			bioawk -v contig_name="$seq_name1" -v srr_var="$srr_number" -v tax_var="$tax_guess" -v perc_var="$perc_id" -v headername="$fsa_head" -v newname="$file_core" -v source_var="$isolation_source" -v rand_var="$rand_id" -v number_var="$file_numbers" -v date_var="$collection_date" -v metgenome_type_var="$metagenome_type" -v srx_var="$srx_number" -v prjn_var="$bioproject" -v samn_var="$biosample" -v molecule_var="$MOLECULE_TYPE" -c fastx '{ print ">" newname " [note= this contig likely does not represent a complete genome] [note= "contig_name" ; closest relative: " tax_var " " perc_var "; WARNING: no viral/plasmid-specific domains were detected. This is probably not a true mobile genetic element.] [organism=" headername " ct" rand_var number_var "] [moltype=genomic DNA][isolation_source=" source_var "] [isolate=ct" rand_var number_var " ] [country=USA] [collection_date=" date_var "] [metagenome_source=" metgenome_type_var "] [note=genome binned from sequencing reads available in " srx_var "] [topology=linear] [Bioproject=" prjn_var "] [Biosample=" samn_var "] [SRA=" srr_var "] [gcode=11]" ; print $seq }' ${feat_tbl2%.comb3.tbl}.fna > sequin_directory/${feat_tbl2%.comb3.tbl}.fsa ;	
			echo "$(tput setaf 3) WARNING: no viral/plasmid-specific domains were detected in "${feat_tbl2%.comb3.tbl}". This is probably not a true mobile genetic element. Scrutinize carefully. $(tput sgr 0)"
		fi
	else
		echo "$(tput setaf 5)tbl file made from: "$feat_tbl2" (viral-domain-containing contig) will be used for sqn generation$(tput sgr 0)" ; 
		cp $feat_tbl2 sequin_directory/${feat_tbl2%.comb3.tbl}.tbl ; 
		if [ -s ${feat_tbl2%.comb3.tbl}.tax_guide.CELLULAR.out ] ; then
			CELL_CHROM=$( cat ${feat_tbl2%.comb3.tbl}.blastn.notnew.out | head -n1 | cut -f3 )
			bioawk -v contig_name="$seq_name1" -v srr_var="$srr_number" -v tax_var="$tax_guess" -v perc_var="$perc_id" -v headername="$fsa_head" -v newname="$file_core" -v source_var="$isolation_source" -v rand_var="$rand_id" -v number_var="$file_numbers" -v date_var="$collection_date" -v metgenome_type_var="$metagenome_type" -v srx_var="$srx_number" -v prjn_var="$bioproject" -v samn_var="$biosample" -v chrom_info="$CELL_CHROM" -v molecule_var="$MOLECULE_TYPE" -c fastx '{ print ">" newname " [note=highly similar to sequence "chrom_info " ; please manually check if this is a transposon especially if there is an annotated reverse transcriptase ] [note= "contig_name" ; closest viral relative: " tax_var " " perc_var "] [organism=" headername " ct" rand_var number_var "; WARNING: no viral/plasmid-specific domains were detected. This is probably not a true mobile genetic element.] [moltype=genomic "molecule_var"][isolation_source=" source_var "] [isolate=ct" rand_var number_var " ] [country=USA] [collection_date=" date_var "] [metagenome_source=" metgenome_type_var "] [note=genome binned from sequencing reads available in " srx_var "] [topology=linear] [Bioproject=" prjn_var "] [Biosample=" samn_var "] [SRA=" srr_var "] [gcode=1]" ; print $seq }' ${feat_tbl2%.comb3.tbl}.fna > sequin_directory/${feat_tbl2%.comb3.tbl}.fsa ;	
			echo "$(tput setaf 3) WARNING: no viral/plasmid-specific domains were detected in "${feat_tbl2%.comb3.tbl}". This is probably not a true mobile genetic element. Scrutinize carefully. $(tput sgr 0)"

		else
			bioawk -v contig_name="$seq_name1" -v srr_var="$srr_number" -v tax_var="$tax_guess" -v perc_var="$perc_id" -v headername="$fsa_head" -v newname="$file_core" -v source_var="$isolation_source" -v rand_var="$rand_id" -v number_var="$file_numbers" -v date_var="$collection_date" -v metgenome_type_var="$metagenome_type" -v srx_var="$srx_number" -v prjn_var="$bioproject" -v samn_var="$biosample" -v molecule_var="$MOLECULE_TYPE" -c fastx '{ print ">" newname " [note= this contig likely does not represent a complete genome] [note= "contig_name" ; closest relative: " tax_var " " perc_var "; WARNING: no viral/plasmid-specific domains were detected. This is probably not a true mobile genetic element.] [organism=" headername " ct" rand_var number_var "] [moltype=genomic DNA][isolation_source=" source_var "] [isolate=ct" rand_var number_var " ] [country=USA] [collection_date=" date_var "] [metagenome_source=" metgenome_type_var "] [note=genome binned from sequencing reads available in " srx_var "] [topology=linear] [Bioproject=" prjn_var "] [Biosample=" samn_var "] [SRA=" srr_var "] [gcode=1]" ; print $seq }' ${feat_tbl2%.comb3.tbl}.fna > sequin_directory/${feat_tbl2%.comb3.tbl}.fsa ;	
			echo "$(tput setaf 3) WARNING: no viral/plasmid-specific domains were detected in "${feat_tbl2%.comb3.tbl}". This is probably not a true mobile genetic element. Scrutinize carefully. $(tput sgr 0)"
		fi		
	fi
done

#making cmt file for assembly data
for nucl_fa in $vd_fastas ; do
	echo "making cmt file!!!!!!"
	input_contig_name=$( head -n1 $nucl_fa | cut -d " " -f 1 | sed 's/|.*//g; s/>//g' ) 
	echo $input_contig_name
	COVERAGE=$( grep "$input_contig_name	" reads_to_all_contigs_over${length_cutoff}nt.coverage.txt | cut -f2 )
	echo $COVERAGE
	echo "Assembly Method	" $ASSEMBLER >> sequin_directory/${nucl_fa%.fasta}.cmt ;
	echo "Genome Coverage	"$COVERAGE"x" >> sequin_directory/${nucl_fa%.fasta}.cmt ;
	echo "Sequencing Technology	Illumina" >> sequin_directory/${nucl_fa%.fasta}.cmt ;
	echo "Annotation Pipeline	Cenote-Taker2" >> sequin_directory/${nucl_fa%.fasta}.cmt ;
	echo "URL	https://github.com/mtisza1/Cenote-Taker2" >> sequin_directory/${nucl_fa%.fasta}.cmt ;done


# Running sequin to generate sqn, gbf, and val files for each genome
echo "$(tput setaf 5)Running tbl2asn for non-circular/non-ITR contigs without viral domains $(tput sgr 0)" ; 

/data/tiszamj/python/linux64.tbl2asn -V vb -t $base_directory/$template_file -X C -p sequin_directory/ ;


cd ..

echo "$(tput setaf 3) FINISHED ANNOTATING CONTIGS WITHOUT CIRCULARITY, ITRS, OR 1 VIRAL DOMAIN $(tput sgr 0)"
