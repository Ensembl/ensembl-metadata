
=pod
=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
=cut

package Bio::EnsEMBL::Utils::MetaData::MetaDataProcessor;
use Bio::EnsEMBL::Utils::MetaData::GenomeInfo;
use Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo;
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw(get_logger);
use strict;
use warnings;

sub new {
  my ($caller, @args) = @_;
  my $class = ref($caller) || $caller;
  my $self = bless({}, $class);
  ($self->{contigs},   $self->{annotation_analyzer},
   $self->{variation}, $self->{compara})
	= rearrange(
			   ['CONTIGS', 'ANNOTATION_ANALYZER', 'VARIATION', 'COMPARA'
			   ],
			   @args);
  $self->{logger} = get_logger();
  return $self;
}

sub process_metadata {
  my ($self, $dbas) = @_;
  # 1. create hash of DBAs
  my $dba_hash = {};
  my $comparas = [];
  for my $dba (grep { $_->dbc()->dbname() !~ /ancestral/ } @{$dbas}) {
	my $type;
	my $species = $dba->species();
	for my $t (qw(core otherfeatures variation funcgen)) {
	  if ($dba->dbc()->dbname() =~ m/$t/) {
		$type = $t;
		last;
	  }
	}
	if (defined $type) {
	  $dba_hash->{$species}{$type} = $dba if defined $type;
	}
	elsif ($dba->dbc()->dbname() =~ m/_compara_/) {
	  push @$comparas, $dba;
	}
  }

  # 2. iterate through each genome
  my $genome_infos = {};
  my $n            = 0;
  my $total        = scalar(keys %$dba_hash);
  while (my ($genome, $dbas) = each %$dba_hash) {
	$self->{logger}
	  ->info("Processing " . $genome . " (" . ++$n . "/$total)");
	$genome_infos->{$genome} = $self->process_genome($genome, $dbas);
  }

  # 3. apply compara
  for my $compara (@$comparas) {
	$self->process_compara($compara, $genome_infos);
  }

  return [values(%$genome_infos)];
} ## end sub process_metadata

sub process_genome {
  my ($self, $genome, $dbas) = @_;
  my $dba = $dbas->{core};

  # get metadata container
  my $meta   = $dba->get_MetaContainer();
  my $dbname = $dba->dbc()->dbname();
  my $size   = get_dbsize($dba);
  my $tableN =
	$dba->dbc()->sql_helper()->execute_single_result(
	-SQL =>
"select count(*) from information_schema.tables where table_schema=?",
	-PARAMS => [$dbname]);
  #my $type = get_type($dbname);
  # TODO replace md with instance of GenomeInfo
  my $md = Bio::EnsEMBL::Utils::MetaData::GenomeInfo->new(
	  -species    => $dba->species(),
	  -species_id => $dba->species_id(),
	  -division   => $meta->get_division() || 'Ensembl',
	  -dbname     => $dbname);
  $md->strain($meta->single_value_by_key('species.strain'));
  $md->serotype($meta->single_value_by_key('species.serotype'));
  $md->name($meta->get_scientific_name());
  $md->taxonomy_id($meta->get_taxonomy_id());
  $md->assembly_id($meta->single_value_by_key('assembly.accession'));
  $md->assembly_name($meta->single_value_by_key('assembly.name'));
  $md->genebuild($meta->single_value_by_key('genebuild.start_date'));
  # get highest assembly level
  $md->assembly_level(
	@{$dba->dbc()->sql_helper()->execute_simple(
		-SQL =>
'select name from coord_system where species_id=? order by rank asc',
		-PARAMS => [$dba->species_id()])}[0]);

  # get list of seq names
  my $seqs_arr = [];
  
  if (defined $self->{contigs}) {
  	my $seqs = {};
  	# 1. get complete list of seq_regions as a hash vs. ENA synonyms
	$dba->dbc()->sql_helper()->execute_no_return(
	  -SQL => q/select distinct s.name, ss.synonym 
	  from coord_system c  
	  join seq_region s using (coord_system_id)  
	  left join seq_region_synonym ss on 
	  	(ss.seq_region_id=s.seq_region_id and ss.external_db_id in 
	  		(select external_db_id from external_db where db_name='EMBL')) 
	  where c.species_id=? and attrib like '%default_version%'/,
	  -PARAMS   => [$dba->species_id()],
	  -CALLBACK => sub {
		my ($name,$acc) = @{shift @_};
		$seqs->{$name} = $acc;
		return;
	  });  
	  	  	
	  # 2. add accessions where the name is flagged as being in ENA
	  $dba->dbc()->sql_helper()->execute_no_return(
	  -SQL => q/
	  select s.name 
	  from coord_system c  
	  join seq_region s using (coord_system_id)  	  
	  join seq_region_attrib sa using (seq_region_id)  
	  where sa.value='ENA' and c.species_id=? and attrib like '%default_version%'/,
	  -PARAMS   => [$dba->species_id()],
	  -CALLBACK => sub {
		my ($acc) = @{shift @_};
		$seqs->{$acc} = $acc;
		return;
	  });
	  	
	  while(my @vals = each %$seqs) {
	  	push @$seqs_arr, \@vals;
	  }	
  }

  $md->sequences($seqs_arr);
  # get toplevel base count
  $md->base_count(
	$dba->dbc()->sql_helper()->execute_single_result(
	  -SQL => q/select sum(length) 
	 from seq_region s 
	 join seq_region_attrib sa using (seq_region_id) 
	 join attrib_type a using (attrib_type_id) 
	 join coord_system cs using (coord_system_id) 
	 where code='toplevel' and species_id=?/,
	  -PARAMS => [$dba->species_id()]));

  # get associated PMIDs
  $md->{publications} = $dba->dbc()->sql_helper()->execute_simple(
	-SQL => q/select distinct dbprimary_acc from 
	  xref
	  join external_db using (external_db_id)
	  join seq_region_attrib sa on (xref.xref_id=sa.value)
	  join attrib_type using (attrib_type_id)
	  join seq_region using (seq_region_id)
	  join coord_system using (coord_system_id)
	  where species_id=? and code='xref_id' and db_name in ('PUBMED')/,
	-PARAMS => [$dba->species_id()]);

  # add aliases
  $md->aliases(
	$dba->dbc()->sql_helper()->execute_simple(
	  -SQL => q/select distinct meta_value from meta
	  where species_id=? and meta_key='species.alias'/,
	  -PARAMS => [$dba->species_id()]));

  if (defined $self->{annotation_analyzer}) {
	# core annotation
	$self->{logger}
	  ->info("Processing " . $dba->species() . " core annotation");
	$md->annotations(
				$self->{annotation_analyzer}->analyze_annotation($dba));
	# features
	my $core_ali =
	  $self->{annotation_analyzer}->analyze_alignments($dba);
	my $other_ali = {};
	$md->features($self->{annotation_analyzer}->analyze_features($dba));
	my $other_features = $dbas->{other_features};
	if (defined $other_features) {
	  $self->{logger}->info(
		 "Processing " . $dba->species() . " otherfeatures annotation");
	  my %features = (%{$md->features()},
					  %{$self->{annotation_analyzer}
						  ->analyze_features($other_features)});
	  $other_ali = $self->{annotation_analyzer}
		->analyze_alignments($other_features);
	  $size += get_dbsize($other_features);
	  $md->features(\%features);
	}
	my $variation = $dbas->{variation};
	# variation
	if (defined $variation) {
	  $self->{logger}->info(
			 "Processing " . $dba->species() . " variation annotation");
	  $md->variations(
		   $self->{annotation_analyzer}->analyze_variation($variation));
	  $size += get_dbsize($variation);
	}
	# BAM
	$self->{logger}
	  ->info("Processing " . $dba->species() . " read aligments");
	my $read_ali = $self->{annotation_analyzer}
	  ->analyze_tracks($md->{species}, $md->{division});
	my %all_ali = (%{$core_ali}, %{$other_ali});
	# add bam tracks by count - use source name
	for my $bam (@{$read_ali->{bam}}) {
	  $all_ali{bam}{$bam->{id}}++;
	}
	$md->other_alignments(\%all_ali);
	$md->db_size($size);

  } ## end if (defined $self->{annotation_analyzer...})

  return $md;
} ## end sub process_genome

sub process_compara {
  my ($self, $compara, $genomes) = @_;
  $self->{logger}
	->info("Processing compara database " . $compara->dbc()->dbname());

  (my $division = $compara->dbc()->dbname()) =~
	s/ensembl_compara_([a-z_]+)_[0-9]+_[0-9]+/$1/;

  my $adaptor = $compara->get_MethodLinkSpeciesSetAdaptor();

  for my $method (
			 qw/PROTEIN_TREES BLASTZ_NET LASTZ_NET TRANSLATED_BLAT_NET/)
  {
	my $mlss_arr = $adaptor->fetch_all_by_method_link_type($method);
	if (defined $mlss_arr && scalar(@{$mlss_arr}) > 0) {
	  my $mlss = $mlss_arr->[0];
	  my $compara_info =
		Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo->new(
								   -DBNAME => $compara->dbc()->dbname(),
								   -DIVISION => $division,
								   -METHOD   => $method,
								   -GENOMES  => []);
	  for my $gdb (@{$mlss->species_set_obj->genome_dbs()}) {
		my $genomeInfo = $genomes->{$gdb->name()};
		if (!defined $genomeInfo) {
		  $self->{logger}
			->info("Creating info object for " . $gdb->name());
		  $genomeInfo = Bio::EnsEMBL::Utils::MetaData::GenomeInfo->new(
			-NAME           => $gdb->name(),
			-SPECIES        => $gdb->name(),
			-DIVISION       => 'Ensembl',
			-SPECIES_ID     => '1',
			-ASSEMBLY_NAME  => $gdb->assembly(),
			-ASSEMBLY_LEVEL => 'unknown',
#				-ASSEMBLY_LEVEL => $gdb->has_karotype() ? 'chromosome' :
			#				  'supercontig',
			-GENEBUILD   => $gdb->genebuild(),
			-TAXONOMY_ID => $gdb->taxon_id(),
			-DBNAME      => $gdb->name() . '_core_n_n');
		  $genomeInfo->base_count(0);
		  $genomes->{$gdb->name()} = $genomeInfo;
		}
		push @{$compara_info->genomes()}, $genomeInfo;

		if (!defined $genomeInfo->compara()) {
		  $genomeInfo->compara([$compara_info]);
		}
		else {
		  push @{$genomeInfo->compara()}, $compara_info;
		}
	  } ## end for my $gdb (@{$mlss->species_set_obj...})
	} ## end if (defined $mlss_arr ...)
  } ## end for my $method (...)

  $self->{logger}->info("Completed processing compara database " .
						$compara->dbc()->dbname());
  return;
} ## end sub process_compara

sub get_dbsize {
  my ($dba) = @_;
  return
	$dba->dbc()->sql_helper()->execute_single_result(
	-SQL =>
"select SUM(data_length + index_length) from information_schema.tables where table_schema=?",
	-PARAMS => [$dba->dbc()->dbname()]);
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::MetaDataProcessor

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new

=head2 process_metadata
Description : Return hashed metadata for the supplied databases
Argument: Arrayref of DBAdaptor objects

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
