#!/usr/bin/perl
 
# use module
use XML::Simple;
 
 
#####   START - Amino Acid Name to Letter Conversion Hash     #####
my %target_lookup_hash = ();
my $tmpvar1;
my $tmpvar2;
open(AMINO_ACID_CONVERSION,"AA_Name_to_letter.txt");#####################              FILE      ########################
while(my $line=<AMINO_ACID_CONVERSION>)
	{
	chomp $line;
	($tmpvar1,$tmpvar2)= split(/\t/, $line);
	$target_lookup_hash{$tmpvar1} = $tmpvar2;
	}
close AMINO_ACID_CONVERSION;
#####   END - Amino Acid Name to Letter Conversion Hash         #####
 
print "finished reading AA name to letter\n";
 
#####   START - N-Terminal Acetylations Hash   #####
my %NterminalAcetylations_hash = ();
$NterminalAcetylations_hash{'A'}='N-acetylalanine';
$NterminalAcetylations_hash{'C'}='N-acetylcysteine';
$NterminalAcetylations_hash{'E'}='N-acetylglutamate';
$NterminalAcetylations_hash{'G'}='N-acetylglycine';
$NterminalAcetylations_hash{'M'}='N-acetylmethionine';
$NterminalAcetylations_hash{'S'}='N-acetylserine';
$NterminalAcetylations_hash{'T'}='N-acetylthreonine';
$NterminalAcetylations_hash{'V'}='N-acetylvaline';
$NterminalAcetylations_hash{'D'}='N-acetylaspartate';
#####   END - N-Terminal Acetylations Hash       #####

print "finished acetylations hash\n"; 
 
#####   START - Read Database of UniProt PTMs              #####
my %PTM_type_hash = (); #keys are PTM ID full name and values are PTM target full name
my %PTM_mass_hash = (); #keys are PTM mass shift rounded to three decimal places and values are PTM ID full name (e.g. Phosphoserine)
my $PTM_ID; # PTM ID full name
my $PTM_Target_Name; # PTM target full name
my $PTM_Mass_Shift;
 
open(PTM_DATABASE,"sub_ptmlist.txt"); # slightly modified database of uniprot ptms#####################  PTM FILE              ########################
while (my $line=<PTM_DATABASE>)
	{
	chomp $line;
	if ($line !~ /ZZ/)
		{
		($tmpvar1, $tmpvar2) = split(/\t/, $line);
		if ($tmpvar1=~ m/^ID/)
			{
			$PTM_ID = $tmpvar2;
			}
		elsif ($tmpvar1=~ m/^TG/)
			{
			$PTM_Target_Name = $target_lookup_hash{$tmpvar2};
			}
		elsif ($tmpvar1=~ m/^MM/)
			{
			$PTM_Mass_Shift = sprintf("%.6f", $tmpvar2);
			}
		 }
	else
		 {
		 push (@{$PTM_type_hash{$PTM_ID}}, $PTM_Target_Name) unless grep{$_ eq $PTM_Target_Name} @{$PTM_type_hash{$PTM_ID}};
		 push (@{$PTM_mass_hash{$PTM_Mass_Shift}}, $PTM_ID) unless grep{$_ eq $PTM_ID} @{$PTM_mass_hash{$PTM_Mass_Shift}};
		 }
	}
close PTM_DATABASE;
#####   END - Read Database of UniProt PTMs   #####

print "finished reading subptmlist\n";  
 
#####   START - Read XML Search Database from UniProt            #####
my %observed_uniprot_ptms = (); #key is accession and value is UniProt PTM and location
my %global_sequence_data = (); #key is accession and value detailed sequence data (length, mass, etc.)
 
my @allUniprotAccessions = ();
my @accessions_with_PTMs = ();
my $xml_deref='uniprot_GPTMD_updated.xml';#####################              MAIN OUTPUT FILE        ########################
open(MYOUTFILE, ">$xml_deref"); #open for write, overwrite

 
# create object
$xml = new XML::Simple (ForceArray => 1,KeyAttr=>[]);
 
print "about to read trimmed xml\n"; 
# read XML file
$data = $xml->XMLin("uniprot_trimmed.xml");#####################          XML DATABASE FILE ########################
 
 
# dereference hash ref
print MYOUTFILE '<?xml version=\'1.0\' encoding=\'UTF-8\'?>', "\n";
print MYOUTFILE '<uniprot xmlns="http://uniprot.org/uniprot" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://uniprot.org/uniprot http://www.uniprot.org/support/docs/uniprot.xsd">',"\n";
foreach $e (@{$data->{entry}})
	{
	my %local_entry_data_hash = ();
	$local_entry_data_hash{dataset}= $e->{dataset}, "\t";
	$local_entry_data_hash{entry_created}= $e->{created}, "\t";
	$local_entry_data_hash{entry_modified}= $e->{modified}, "\t";
	$local_entry_data_hash{entry_version}= $e->{version}, "\n";
	my $first_accession = $e->{accession}->[0]; #could go back later and add the other accession numbers??? 
	push (@allUniprotAccessions,$first_accession);
	$local_entry_data_hash{name}= $e->{name}->[0];
	$local_entry_data_hash{fullName}= $e->{protein}->[0]->{recommendedName}->[0]->{fullName}->[0];
	if (defined $local_entry_data_hash{fullName}) 
		{
		if(ref($local_entry_data_hash{fullName}) eq "HASH")
			{
			$local_entry_data_hash{fullName} = $first_accession;
			}  
		}
	else  
		{
		$local_entry_data_hash{fullName} = $first_accession;
		}
	$local_entry_data_hash{gene}=$e->{gene}->[0]->{name}->[0]->{content};
	$local_entry_data_hash{organism_name}=$e->{organism}->[0]->{name}->[0]->{content}, "\n";
	$local_entry_data_hash{dbReference_id}=$e->{organism}->[0]->{dbReference}->[0]->{id};
	$local_entry_data_hash{dbReference_type}=$e->{organism}->[0]->{dbReference}->[0]->{type};
	$local_entry_data_hash{proteinExistence}=$e->{proteinExistence}->[0]->{type};
	$local_entry_data_hash{length}=$e->{sequence}->[0]->{length};
	$local_entry_data_hash{mass}=$e->{sequence}->[0]->{mass};
	$local_entry_data_hash{checksum}=$e->{sequence}->[0]->{checksum};
	$local_entry_data_hash{modified}=$e->{sequence}->[0]->{modified};
	$local_entry_data_hash{version}=$e->{sequence}->[0]->{version};
	(my $aminoAcidSequence =$e->{sequence}->[0]->{content}) =~ s/\s//g; #gets sequence with no whitespace
	$local_entry_data_hash{content}=$aminoAcidSequence;
 
	my $feature_array_ref = $e->{feature};
	foreach my $feature (@$feature_array_ref)
		{
		 if (${$feature}{type}eq'modified residue')
			{
			push (@{$observed_uniprot_ptms{$first_accession}{${$feature}{location}->[0]->{position}->[0]->{position}}},${$feature}{description});
			}
		 }
	$global_sequence_data{$first_accession}=\%local_entry_data_hash;
	}
#####   END - Read XML Search Database from UniProt #####
 
print "starting to read PSMs.tsv\n";  
 
#####   START - Morpheus Input             #####
my $morpheus_PSMs_file='aggregate.PSMs.tsv';#####################              MORPHEUS RESULT FILE              ########################
open(MORPHEUS_RESULTS,$morpheus_PSMs_file);
my $header=<MORPHEUS_RESULTS>;   #Header is read here and skipped
while (<MORPHEUS_RESULTS>)
	{
	chomp;
	my @indiv_peptide_ID_data = ();
	@indiv_peptide_ID_data = split(/\t/, $_);
	last if ($indiv_peptide_ID_data[25]<7);##### Morpheus score 7 is the minimum threshold for adding a new ptm to the database. This is just a guess.
	my $protein_description = $indiv_peptide_ID_data[13];
	my @protein_description_fields = split (/\|/,$protein_description);
	my $accession_number = $protein_description_fields[1];
	if (($indiv_peptide_ID_data[26])&&(grep(!/DECOY/, $indiv_peptide_ID_data[13]))&&(( grep {$_ eq $accession_number} @allUniprotAccessions ))) #checks if Target=TRUE and Not DECOY
		{
		 
		my $base_peptide_sequence = $indiv_peptide_ID_data[12];
		my $start_residue = $indiv_peptide_ID_data[14];
		my $precursor_mass_error = sprintf "%.6f",$indiv_peptide_ID_data[18]; 
		my $seq_temp = ${$global_sequence_data{$accession_number}}{content};
		my @possible_precursor_mass_errors = ();
		foreach my $mass_shift (keys %PTM_mass_hash)
			{
			 my $low = $mass_shift-0.015;
			 my $high = $mass_shift+0.015;
			if (($precursor_mass_error>$low)&&($precursor_mass_error<$high))
				{
				push (@possible_precursor_mass_errors,$mass_shift);
				}
			}
		 if ((scalar @possible_precursor_mass_errors)>0)
			{
			foreach my $pme (@possible_precursor_mass_errors)
				{
				foreach my $type_of_PTM (@{$PTM_mass_hash{$pme}})
					{
					foreach my $modified_AA (@{$PTM_type_hash{$type_of_PTM}})
						{
						my $offset = 0;
						my $result = index($base_peptide_sequence, $modified_AA, $offset);
						while ($result != -1)
							{
							my $position_in_the_protein = ($start_residue+$result);
							if (index($type_of_PTM, 'N-acetyl') != -1)
								{
								if ($position_in_the_protein eq "2"&&((substr ${$global_sequence_data{$accession_number}}{content},$result,1) eq $modified_AA))
									{
									push (@{$observed_uniprot_ptms{$accession_number}{$position_in_the_protein}},$type_of_PTM);
									}
								}
							elsif ((substr $base_peptide_sequence,$result,1) eq $modified_AA)
								{
								if ((substr ${$global_sequence_data{$accession_number}}{content},0,1) eq "X")
									{
									$position_in_the_protein = $position_in_the_protein + 1;
									my $base_in_the_target = substr ${$global_sequence_data{$accession_number}}{content},$result,1;
									push (@{$observed_uniprot_ptms{$accession_number}{$position_in_the_protein}},$type_of_PTM);
									}
								else
									{
									my $base_in_the_target = substr ${$global_sequence_data{$accession_number}}{content},$result,1;
									push (@{$observed_uniprot_ptms{$accession_number}{$position_in_the_protein}},$type_of_PTM);
									}
								}
							else
								{
								my $base_in_the_target = substr ${$global_sequence_data{$accession_number}}{content},$result,1;
								}
							$offset = $result + 1;
							$result = index($base_peptide_sequence, $modified_AA, $offset);
							}
						}
					}
				}
			}
		 #special cases#################
		
		 #SPECIAL CASE 1: N-terminal acetylation
		 if(($precursor_mass_error>(-89.029921-0.02))&&($precursor_mass_error<(-89.029921+0.02))&&($start_residue eq '1'))
			 {
			 my $second_AA = substr $base_peptide_sequence, 1,1;
			 if (defined $NterminalAcetylations_hash{$second_AA}&&((substr ${$global_sequence_data{$accession_number}}{content},2,1) eq $second_AA))
				  {
				  push (@{$observed_uniprot_ptms{$accession_number}{2}},$NterminalAcetylations_hash{$second_AA});
				  }
			 }
		 #END special cases#############
		}
	}
close MORPHEUS_RESULTS;
#####   END - Morpheus Input  #####
 
 
#####   START - Compile Array of Accession Numbers with PTMs             #####
foreach my $AN (sort keys %observed_uniprot_ptms)
	{
	push (@accessions_with_PTMs,$AN);
	}
#####   END - Compile Array of Accession Numbers with PTMs  #####
 
print "writing new xml\n"; 
 
#####   START - Write New XML Database with Novel PTMs        #####
foreach my $AN (sort keys %global_sequence_data)
	{
	print MYOUTFILE '<entry dataset="', ${$global_sequence_data{$AN}}{dataset},'" created="', ${$global_sequence_data{$AN}}{entry_created},'" modified="', ${$global_sequence_data{$AN}}{entry_modified},'" version="', ${$global_sequence_data{$AN}}{entry_version},'">',"\n";
	print MYOUTFILE '<accession>',$AN ,'</accession>',"\n";
	print MYOUTFILE '<name>',${$global_sequence_data{$AN}}{name} ,'</name>',"\n";
	print MYOUTFILE '<protein>',"\n";
	print MYOUTFILE '<recommendedName>',"\n";
	print MYOUTFILE '<fullName>',${$global_sequence_data{$AN}}{fullName},'</fullName>',"\n";
	print MYOUTFILE '</recommendedName>',"\n";
	print MYOUTFILE '</protein>',"\n";
	print MYOUTFILE '<gene>',"\n";
	print MYOUTFILE '<name type="primary">',${$global_sequence_data{$AN}}{gene},'</name>',"\n";
	print MYOUTFILE '</gene>',"\n";
	print MYOUTFILE '<organism>',"\n";
	print MYOUTFILE '<name type="scientific">',${$global_sequence_data{$AN}}{organism_name} ,'</name>',"\n";
	print MYOUTFILE '<dbReference type="', ${$global_sequence_data{$AN}}{dbReference_type},'" id="', ${$global_sequence_data{$AN}}{dbReference_id},'"/>',"\n";
	print MYOUTFILE '</organism>',"\n";
	print MYOUTFILE '<proteinExistence type="', ${$global_sequence_data{$AN}}{proteinExistence},'"/>',"\n";
 
	if (grep /$AN/, @accessions_with_PTMs)
		{
		foreach my $base (sort keys %{ $observed_uniprot_ptms{$AN} })
			{
			my @unique_ptms = do { my %seen; grep { !$seen{$_}++ } @{$observed_uniprot_ptms{$AN}{$base}} };
			foreach my $ptm (@unique_ptms)
				{
				print MYOUTFILE '<feature type="modified residue" description="',$ptm,'" evidence="3">', "\n";
				print MYOUTFILE "\t",'<location>', "\n";
				print MYOUTFILE "\t\t",'<position position="',$base,'"/>', "\n";
				print MYOUTFILE "\t",'</location>', "\n";
				print MYOUTFILE '</feature>', "\n";
				}
			}
		}
 
	print MYOUTFILE '<sequence length="', ${$global_sequence_data{$AN}}{length},'" mass="',${$global_sequence_data{$AN}}{mass},'" checksum="',${$global_sequence_data{$AN}}{checksum},'" modified="',${$global_sequence_data{$AN}}{modified},'" version="',${$global_sequence_data{$AN}}{version},'">',"\n";
	print MYOUTFILE ${$global_sequence_data{$AN}}{content};
	print MYOUTFILE "\n";
	print MYOUTFILE '</sequence>',"\n";
	print MYOUTFILE '</entry>',"\n";
	}
 
 
print MYOUTFILE '<copyright>', "\n";
print MYOUTFILE 'Copyrighted by the UniProt Consortium, see http://www.uniprot.org/terms Distributed under the Creative Commons Attribution-NoDerivs License', "\n";
print MYOUTFILE '</copyright>', "\n";
print MYOUTFILE '</uniprot>', "\n";

close MYOUTFILE;
#####   END - Write New XML Database with Novel PTMs            #####