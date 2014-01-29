
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
	elsif ($dba->dbc()->dbname() =~ m/compara/) {
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
	process_compara($compara, $genome_infos);
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
  my $md =
	Bio::EnsEMBL::Utils::MetaData::GenomeInfo->new(
	-species    => $dba->species(),
	-species_id => $dba->species_id(),
	-strain     => $meta->single_value_by_key('species.strain') || '',
	-serotype   => $meta->single_value_by_key('species.serotype') || '',
	-name       => $meta->get_scientific_name() || '',
	-taxonomy_id => $meta->get_taxonomy_id() || '',
	-assembly_id => $meta->single_value_by_key('assembly.accession') ||
	  '',
	-assembly_name => $meta->single_value_by_key('assembly.name') || '',
	-genebuild => $meta->single_value_by_key('genebuild.start_date') ||
	  '',
	-division => $meta->get_division() || 'Ensembl',
	-dbname => $dbname);

  # get highest assembly level
  $md->assembly_level(
	@{$dba->dbc()->sql_helper()->execute_simple(
		-SQL =>
'select name from coord_system where species_id=? order by rank asc',
		-PARAMS => [$dba->species_id()])}[0]);

  # get list of seq names
  my $seqs = {};
  if (defined $self->{contigs}) {
	$dba->dbc()->sql_helper()->execute_no_return(
	  -SQL => q/select s.name,ss.synonym from coord_system c 
join seq_region s using (coord_system_id) 
left join seq_region_synonym ss using (seq_region_id)
where c.species_id=?/,
	  -PARAMS   => [$dba->species_id()],
	  -CALLBACK => sub {
		my @row = @{shift @_};

		$seqs->{$row[0]} = 1;
		if (defined $row[1]) {
		  $seqs->{$row[1]} = 1;
		}
		return;
	  });
  }

  $md->sequences([keys(%$seqs)]);
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
	$md->features($self->{annotation_analyzer}->analyze_features($dba));
	my $other_features = $dbas->{other_features};
	if (defined $other_features) {
	  $self->{logger}->info(
		 "Processing " . $dba->species() . " otherfeatures annotation");
	  my %features = (%{$md->features()},
					  %{$self->{annotation_analyzer}
						  ->analyze_features($other_features)});
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
	  $self->{logger}->info(
			 "Processing " . $dba->species() . " read aligments");
	$md->read_alignments($self->{annotation_analyzer}
					 ->analyze_tracks($md->{species}, $md->{division}));
	$md->db_size($size);

  } ## end if (defined $self->{annotation_analyzer...})

  return $md;
} ## end sub process_genome

sub process_compara {
  my ($self, $compara, $genomes) = @_;
  return;
}

#  sub process_metadata_old {
#	my ($self, $dbas) = @_;
#	my $metadata;    # arrayref
#	my $dba_hash = {};
#	for my $dba (grep { $_->dbc()->dbname() !~ /ancestral/ } @{$dbas}) {
#	  my $type;
#	  my $species = $dba->species();
#	  for my $t (qw(core otherfeatures variation funcgen compara)) {
#		if ($dba->dbc()->dbname() =~ m/$t/) {
#		  $type = $t;
#		  last;
#		}
#	  }
#	  $dba_hash->{$type}{$species} = $dba if defined $type;
#	}
#	# build a hash of pan species
#	my $pan_species = {};
#	my $pan_compara = $dba_hash->{compara}{pan_homology};
#	if (defined $pan_compara) {
#	  (my $mlss) = @{$pan_compara->get_MethodLinkSpeciesSetAdaptor()
#		  ->fetch_all_by_method_link_type("PROTEIN_TREES")};
#	  for my $gdb (@{$mlss->species_set_obj->genome_dbs()}) {
#		$pan_species->{$gdb->name()} = 1;
#	  }
#	}
#	my $n     = 0;
#	my $total = scalar(values %{$dba_hash->{core}});
#	for my $dba (values %{$dba_hash->{core}}) {
#	  eval {
#		$self->{logger}->info(
#			"Processing " . $dba->species() . " (" . ++$n . "/$total)");
#		# get metadata container
#		my $meta   = $dba->get_MetaContainer();
#		my $dbname = $dba->dbc()->dbname();
#		my $size   = get_dbsize($dba);
#		my $tableN =
#		  $dba->dbc()->sql_helper()->execute_single_result(
#		  -SQL =>
#"select count(*) from information_schema.tables where table_schema=?",
#		  -PARAMS => [$dbname]);
#		#my $type = get_type($dbname);
#		# TODO replace md with instance of GenomeInfo
#		my $md =
#		  Bio::EnsEMBL::Utils::MetaData::GenomeInfo->new(
#		  -species    => $dba->species(),
#		  -species_id => $dba->species_id(),
#		  -strain => $meta->single_value_by_key('species.strain') || '',
#		  -serotype => $meta->single_value_by_key('species.serotype')
#			|| '',
#		  -name        => $meta->get_scientific_name() || '',
#		  -taxonomy_id => $meta->get_taxonomy_id()     || '',
#		  -assembly_id =>
#			$meta->single_value_by_key('assembly.accession') || '',
#		  -assembly_name => $meta->single_value_by_key('assembly.name')
#			|| '',
#		  -genebuild =>
#			$meta->single_value_by_key('genebuild.start_date') || '',
#		  -division => $meta->get_division() || 'Ensembl',
#		  -dbname => $dbname);
#	 #	  my $mda = {
#	 #		 species    => $dba->species(),
#	 #		 species_id => $dba->species_id(),
#	 #		 strain => $meta->single_value_by_key('species.strain') || '',
#	 #		 serotype => $meta->single_value_by_key('species.serotype') ||
#	 #		   '',
#	 #		 name        => $meta->get_scientific_name() || '',
#	 #		 taxonomy_id => $meta->get_taxonomy_id()     || '',
#	 #		 assembly_id => $meta->single_value_by_key('assembly.accession')
#	 #		   || '',
#	 #		 assembly_name => $meta->single_value_by_key('assembly.name') ||
#	 #		   '',
#	 #		 genebuild => $meta->single_value_by_key('genebuild.start_date')
#	 #		   || '',
#	 #		 division => $meta->get_division() || 'Ensembl',
#	 #		 dbname => $dbname};
#
#		# get highest assembly level
#		$md->assembly_level(
#		  @{$dba->dbc()->sql_helper()->execute_simple(
#			  -SQL =>
#'select name from coord_system where species_id=? order by rank asc',
#			  -PARAMS => [$dba->species_id()])}[0]);
#
#		# get list of seq names
#		my $seqs = {};
#		if (defined $self->{contigs}) {
#		  $dba->dbc()->sql_helper()->execute_no_return(
#			-SQL => q/select s.name,ss.synonym from coord_system c
#join seq_region s using (coord_system_id)
#left join seq_region_synonym ss using (seq_region_id)
#where c.species_id=?/,
#			-PARAMS   => [$dba->species_id()],
#			-CALLBACK => sub {
#			  my @row = @{shift @_};
#
#			  $seqs->{$row[0]} = 1;
#			  if (defined $row[1]) {
#				$seqs->{$row[1]} = 1;
#			  }
#			  return;
#			});
#		}
#
#		$md->sequences([keys(%$seqs)]);
#		# get toplevel base count
#		$md->base_count(
#		  $dba->dbc()->sql_helper()->execute_single_result(
#			-SQL => q/select sum(length)
#	 from seq_region s
#	 join seq_region_attrib sa using (seq_region_id)
#	 join attrib_type a using (attrib_type_id)
#	 join coord_system cs using (coord_system_id)
#	 where code='toplevel' and species_id=?/,
#			-PARAMS => [$dba->species_id()]));
#
#		# get associated PMIDs
#		$md->{publications} = $dba->dbc()->sql_helper()->execute_simple(
#		  -SQL => q/select distinct dbprimary_acc from
#	  xref
#	  join external_db using (external_db_id)
#	  join seq_region_attrib sa on (xref.xref_id=sa.value)
#	  join attrib_type using (attrib_type_id)
#	  join seq_region using (seq_region_id)
#	  join coord_system using (coord_system_id)
#	  where species_id=? and code='xref_id' and db_name in ('PUBMED')/,
#		  -PARAMS => [$dba->species_id()]);
#
#		# add aliases
#
#		if (defined $self->{annotation_analyzer}) {
#		  # core annotation
#		  $self->{logger}->info(
#				  "Processing " . $dba->species() . " core annotation");
#		  $md->annotation(
#				$self->{annotation_analyzer}->analyze_annotation($dba));
#		  # features
#		  $md->features(
#				  $self->{annotation_analyzer}->analyze_features($dba));
#		  my $other_features =
#			$dba_hash->{otherfeatures}{$dba->species()};
#		  if (defined $other_features) {
#			$self->{logger}->info("Processing " .
#						 $dba->species() . " otherfeatures annotation");
#			my %features = (%{$md->features()},
#							%{$self->{annotation_analyzer}
#								->analyze_features($other_features)});
#			$size += get_dbsize($other_features);
#			$md->features(\%features);
#		  }
#		  # variation
#		  my $variation = $dba_hash->{variation}{$dba->species()};
#		  if (defined $variation) {
#			$self->{logger}->info("Processing " .
#							 $dba->species() . " variation annotation");
#			$md->variation($self->{annotation_analyzer}
#						   ->analyze_variation($variation));
#			$size += get_dbsize($variation);
#		  }
#		  # BAM
#		  $md->read_alignments($self->{annotation_analyzer}
#					 ->analyze_tracks($md->{species}, $md->{division}));
#		  # compara
#		  (my $compara_div = lc $md->{division}) =~ s/ensembl//;
#		  my $compara = $dba_hash->{compara}{$compara_div};
#		  if (defined $compara) {
#			$self->{logger}->info(
#			   "Processing " . $dba->species() . " compara annotation");
#			$md->division_compara($self->{annotation_analyzer}
#								  ->analyze_compara($compara, $dba));
#		  }
#		  if (defined $pan_species->{$dba->species()}) {
#			$md->pan_compara($pan_species);
#		  }
#		  $md->db_size($size);
#		} ## end if (defined $self->{annotation_analyzer...})
#		push @{$metadata->{genome}}, $md;
#	  };
#	  if ($@) {
#		throw "Could not get metadata for species " .
#		  $dba->species() . ":" . $@;
#	  }
#	} ## end for my $dba (values %{$dba_hash...})
#
#	if (defined $metadata->{genome}) {
#	  $metadata->{genome} = [
#		sort {
#		  $a->{division} cmp $b->{division} or
#			$a->{name} cmp $b->{name}
#		} @{$metadata->{genome}}];
#	}
#	return $metadata;
#  } ## end sub process_metadata_old

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
