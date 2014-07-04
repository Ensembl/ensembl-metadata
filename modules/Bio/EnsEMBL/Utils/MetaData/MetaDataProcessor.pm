
=pod
=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 
=cut

package Bio::EnsEMBL::Utils::MetaData::MetaDataProcessor;
use Bio::EnsEMBL::Utils::MetaData::GenomeInfo;
use Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use Log::Log4perl qw(get_logger);
use strict;
use warnings;

sub new {
  my ( $caller, @args ) = @_;
  my $class = ref($caller) || $caller;
  my $self = bless( {}, $class );
  ( $self->{contigs}, $self->{annotation_analyzer},
	$self->{variation}, $self->{compara}, $self->{info_adaptor},
	$self->{force_update} )
	= rearrange(
				 [ 'CONTIGS',      'ANNOTATION_ANALYZER',
				   'VARIATION',    'COMPARA',
				   'INFO_ADAPTOR', 'FORCE_UPDATE' ],
				 @args );
  $self->{logger} = get_logger();
  return $self;
}

sub process_metadata {
  my ( $self, $dbas ) = @_;
  # 1. create hash of DBAs
  my $dba_hash = {};
  my $comparas = [];
  for my $dba ( grep { $_->dbc()->dbname() !~ /ancestral/ } @{$dbas} ) {
	my $type;
	my $species = $dba->species();
	for my $t (qw(core otherfeatures variation funcgen)) {
	  if ( $dba->dbc()->dbname() =~ m/$t/ ) {
		$type = $t;
		last;
	  }
	}
	if ( defined $type ) {
	  $dba_hash->{$species}{$type} = $dba if defined $type;
	}
	elsif ( $dba->dbc()->dbname() =~ m/_compara_/ ) {
	  push @$comparas, $dba;
	}
  }

  # 2. iterate through each genome
  my $genome_infos = {};
  my $n            = 0;
  my $total        = scalar( keys %$dba_hash );
  while ( my ( $genome, $dbas ) = each %$dba_hash ) {
	$self->{logger}
	  ->info( "Processing " . $genome . " (" . ++$n . "/$total)" );
	$genome_infos->{$genome} = $self->process_genome($dbas);
  }

  # 3. apply compara
  for my $compara (@$comparas) {
	$self->process_compara( $compara, $genome_infos );
  }

  return [ values(%$genome_infos) ];
} ## end sub process_metadata

sub process_genome {
  my ( $self, $dbas ) = @_;
  my $dba = $dbas->{core};
  $dba->dbc()->reconnect_when_lost(1);
  # get metadata container
  my $meta   = $dba->get_MetaContainer();
  my $dbname = $dba->dbc()->dbname();
  my $size   = get_dbsize($dba);
  my $tableN =
	$dba->dbc()->sql_helper()->execute_single_result(
	-SQL =>
"select count(*) from information_schema.tables where table_schema=?",
	-PARAMS => [$dbname] );
  my $md =
	Bio::EnsEMBL::Utils::MetaData::GenomeInfo->new(
						-species    => $dba->species(),
						-species_id => $dba->species_id(),
						-division => $meta->get_division() || 'Ensembl',
						-dbname   => $dbname );
  if ( defined $self->{info_adaptor} ) {
	my $extant_md =
	  $self->{info_adaptor}->fetch_by_species( $md->species() );
	if ( defined $extant_md ) {
	  if ( defined $self->{force_update} ) {
		$self->{logger}->info( "Reusing existing genome_id " .
						$extant_md->dbID() . " for " . $md->species() );
		$md->dbID( $extant_md->dbID() );
		$md->adaptor( $extant_md->adaptor() );
	  }
	  else {
		# reuse existing, unused
		return $extant_md;
	  }
	}
  }
  $md->strain( $meta->single_value_by_key('species.strain') );
  $md->serotype( $meta->single_value_by_key('species.serotype') );
  $md->name( $meta->get_display_name() );
  $md->taxonomy_id( $meta->get_taxonomy_id() );
  $md->assembly_id( $meta->single_value_by_key('assembly.accession') );
  $md->assembly_name( $meta->single_value_by_key('assembly.name') );
  $md->genebuild( $meta->single_value_by_key('genebuild.start_date') );
  # get highest assembly level
  $md->assembly_level(
	@{$dba->dbc()->sql_helper()->execute_simple(
		-SQL =>
'select name from coord_system where species_id=? order by rank asc',
		-PARAMS => [ $dba->species_id() ] ) }[0] );

  # get list of seq names
  my $seqs_arr = [];

  if ( defined $self->{contigs} ) {
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
	  -PARAMS   => [ $dba->species_id() ],
	  -CALLBACK => sub {
		my ( $name, $acc ) = @{ shift @_ };
		$seqs->{$name} = $acc;
		return;
	  } );

	# 2. add accessions where the name is flagged as being in ENA
	$dba->dbc()->sql_helper()->execute_no_return(
	  -SQL => q/
	  select s.name 
	  from coord_system c  
	  join seq_region s using (coord_system_id)  	  
	  join seq_region_attrib sa using (seq_region_id)  
	  where sa.value='ENA' and c.species_id=? and attrib like '%default_version%'/,
	  -PARAMS   => [ $dba->species_id() ],
	  -CALLBACK => sub {
		my ($acc) = @{ shift @_ };
		$seqs->{$acc} = $acc;
		return;
	  } );

	while ( my ( $key, $acc ) = each %$seqs ) {
	  push @$seqs_arr, { name => $key, acc => $acc };
	}
  } ## end if ( defined $self->{contigs...})

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
	  -PARAMS => [ $dba->species_id() ] ) );

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
	-PARAMS => [ $dba->species_id() ] );

  # add aliases
  $md->aliases(
	$dba->dbc()->sql_helper()->execute_simple(
	  -SQL => q/select distinct meta_value from meta
	  where species_id=? and meta_key='species.alias'/,
	  -PARAMS => [ $dba->species_id() ] ) );

  if ( defined $self->{annotation_analyzer} ) {
	# core annotation
	$self->{logger}
	  ->info( "Processing " . $dba->species() . " core annotation" );
	$md->annotations(
			   $self->{annotation_analyzer}->analyze_annotation($dba) );
	# features
	my $core_ali =
	  $self->{annotation_analyzer}->analyze_alignments($dba);
	my $other_ali = {};
	$md->features(
				 $self->{annotation_analyzer}->analyze_features($dba) );
	my $other_features = $dbas->{otherfeatures};
	if ( defined $other_features ) {
	  $self->{logger}->info(
		"Processing " . $dba->species() . " otherfeatures annotation" );
	  my %features = ( %{ $md->features() },
					   %{$self->{annotation_analyzer}
						   ->analyze_features($other_features) } );
	  $other_ali = $self->{annotation_analyzer}
		->analyze_alignments($other_features);
	  $size += get_dbsize($other_features);
	  $md->features( \%features );
	}
	my $variation = $dbas->{variation};
	# variation
	if ( defined $variation ) {
	  $self->{logger}->info(
			"Processing " . $dba->species() . " variation annotation" );
	  $md->variations(
		  $self->{annotation_analyzer}->analyze_variation($variation) );
	  $size += get_dbsize($variation);
	}
	# BAM
	$self->{logger}
	  ->info( "Processing " . $dba->species() . " read aligments" );
	my $read_ali = $self->{annotation_analyzer}
	  ->analyze_tracks( $md->{species}, $md->{division} );
	my %all_ali = ( %{$core_ali}, %{$other_ali} );
	# add bam tracks by count - use source name
	for my $bam ( @{ $read_ali->{bam} } ) {
	  $all_ali{bam}{ $bam->{id} }++;
	}
	print Dumper(%all_ali);
	$md->other_alignments( \%all_ali );
	$md->db_size($size);

  } ## end if ( defined $self->{annotation_analyzer...})
  $dba->dbc()->disconnect_if_idle();
  return $md;
} ## end sub process_genome

my $DIVISION_NAMES = { 'bacteria'     => 'EnsemblBacteria',
					   'plants'       => 'EnsemblPlants',
					   'protists'     => 'EnsemblProtists',
					   'fungi'        => 'EnsemblFungi',
					   'metazoa'      => 'EnsemblMetazoa',
					   'pan_homology' => 'EnsemblPan' };

sub process_compara {
  my ( $self, $compara, $genomes ) = @_;
  $self->{logger}->info(
		   "Processing compara database " . $compara->dbc()->dbname() );

  ( my $division = $compara->dbc()->dbname() ) =~
	s/ensembl_compara_([a-z_]+)_[0-9]+_[0-9]+/$1/;

  $division = $DIVISION_NAMES->{$division} || $division;

  my $adaptor = $compara->get_MethodLinkSpeciesSetAdaptor();

  for my $method (
	qw/PROTEIN_TREES BLASTZ_NET LASTZ_NET TRANSLATED_BLAT TRANSLATED_BLAT_NET SYNTENY/
	)
  {
	# group by species_set
	my $mlss_by_ss = {};
	for
	  my $mlss ( @{ $adaptor->fetch_all_by_method_link_type($method) } )
	{
	  push @{ $mlss_by_ss->{ $mlss->species_set_obj()->dbID() } },
		$mlss;
	}

	for my $mlss_list ( values %$mlss_by_ss ) {

	  my $dbs = {};
	  my $ss_name;
	  for my $mlss ( @{$mlss_list} ) {
		$ss_name ||= $mlss->species_set_obj()->get_tagvalue('name');
		for my $gdb ( @{ $mlss->species_set_obj()->genome_dbs() } ) {
		  $dbs->{ $gdb->name() } = $gdb;
		}
	  }

	  my $compara_info =
		Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo->new(
								   -DBNAME => $compara->dbc()->dbname(),
								   -DIVISION => $division,
								   -METHOD   => $method,
								   -SET_NAME => $ss_name,
								   -GENOMES  => [] );

	  if ( defined $self->{info_adaptor} ) {
		my $extant_compara_info = $self->{info_adaptor}->();
		if ( defined $extant_compara_info ) {
		  if ( defined $self->{force_update} ) {
			$compara_info->dbID( $extant_compara_info->dbID() );
			$compara_info->adaptor( $extant_compara_info->adaptor() );
		  }
		  else {
			return $extant_compara_info;
		  }
		}
	  }

	  for my $gdb ( values %{$dbs} ) {
		my $genomeInfo = $genomes->{ $gdb->name() };
		# have we got one in the database already?
		if ( !defined $genomeInfo && defined $self->{info_adaptor} ) {
		  $genomeInfo =
			$self->{info_adaptor}->fetch_by_species( $gdb->name() );
		}

		# last attempt, create one
		if ( !defined $genomeInfo ) {
		  $self->{logger}
			->info( "Creating info object for " . $gdb->name() );
		  # get core dba
		  my $dba;
		  eval {
			$dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $gdb->name(),
														  'core' );
		  };
		  if ( defined $dba ) {
			$genomeInfo = $self->process_genome( { core => $dba } );
		  }
		  else {
			$genomeInfo =
			  Bio::EnsEMBL::Utils::MetaData::GenomeInfo->new(
								   -NAME           => $gdb->name(),
								   -SPECIES        => $gdb->name(),
								   -DIVISION       => 'Ensembl',
								   -SPECIES_ID     => '1',
								   -ASSEMBLY_NAME  => $gdb->assembly(),
								   -ASSEMBLY_LEVEL => 'unknown',
								   -GENEBUILD      => $gdb->genebuild(),
								   -TAXONOMY_ID    => $gdb->taxon_id(),
								   -DBNAME => $gdb->name() . '_core_n_n'
			  );
		  }
		  $genomeInfo->base_count(0);
		  $genomes->{ $gdb->name() } = $genomeInfo;
		} ## end if ( !defined $genomeInfo)
		push @{ $compara_info->genomes() }, $genomeInfo;

		if ( !defined $genomeInfo->compara() ) {
		  $genomeInfo->compara( [$compara_info] );
		}
		else {
		  push @{ $genomeInfo->compara() }, $compara_info;
		}
	  } ## end for my $gdb ( values %{...})
	} ## end for my $mlss_list ( values...)
  } ## end for my $method ( ...)

  $self->{logger}->info( "Completed processing compara database " .
						 $compara->dbc()->dbname() );
  return;
} ## end sub process_compara

sub get_dbsize {
  my ($dba) = @_;
  return
	$dba->dbc()->sql_helper()->execute_single_result(
	-SQL =>
"select SUM(data_length + index_length) from information_schema.tables where table_schema=?",
	-PARAMS => [ $dba->dbc()->dbname() ] );
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
