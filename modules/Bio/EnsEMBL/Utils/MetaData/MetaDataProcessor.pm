
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
  ($self->{contigs}, $self->{annotation_analyzer}) = rearrange(['CONTIGS', 'ANNOTATION_ANALYZER', 'VARIATION', 'COMPARA'], @args);
  $self->{logger} = get_logger();
  return $self;
}

sub process_metadata {
  my ($self, $dbas) = @_;
  my $metadata;    # arrayref
  my $dba_hash = {};
  for my $dba (grep { $_->dbc()->dbname() !~ /ancestral/ } @{$dbas}) {
	my $type;
	my $species = $dba->species();
	for my $t (qw(core otherfeatures variation funcgen compara)) {
	  if ($dba->dbc()->dbname() =~ m/$t/) {
		$type = $t;
		last;
	  }
	}
	$dba_hash->{$type}{$species} = $dba if defined $type;
  }
  # build a hash of pan species
  my $pan_species = {};
  my $pan_compara = $dba_hash->{compara}{pan_homology};
  if (defined $pan_compara) {
	(my $mlss) = @{$pan_compara->get_MethodLinkSpeciesSetAdaptor()->fetch_all_by_method_link_type("PROTEIN_TREES")};
	for my $gdb (@{$mlss->species_set_obj->genome_dbs()}) {
	  $pan_species->{$gdb->name()} = 1;
	}
  }

  for my $dba (values %{$dba_hash->{core}}) {
	eval {
	  $self->{logger}->info("Processing " . $dba->species());
	  # get metadata container
	  my $meta = $dba->get_MetaContainer();
	  my $md = {species       => $dba->species(),
				species_id    => $dba->species_id(),
				name          => $meta->get_scientific_name() || '',
				taxonomy_id   => $meta->get_taxonomy_id() || '',
				assembly_id   => $meta->single_value_by_key('assembly.accession') || '',
				assembly_name => $meta->single_value_by_key('assembly.name') || '',
				genebuild     => $meta->single_value_by_key('genebuild.start_date') || '',
				division      => $meta->get_division() || '',
				dbname        => $dba->dbc()->dbname()};
	  # get list of seqlevel contigs
	  if (defined $self->{contigs}) {
		my $slice_adaptor = $dba->get_SliceAdaptor();
		for my $contig (@{$slice_adaptor->fetch_all("contig")}) {
		  push @{$md->{accession}}, $contig->seq_region_name();
		}
	  }
	  if (defined $self->{annotation_analyzer}) {
		# core annotation
		$self->{logger}->info("Processing " . $dba->species() . " core annotation");
		$md->{annotation} = $self->{annotation_analyzer}->analyze_annotation($dba);
		# features
		$md->{features} = $self->{annotation_analyzer}->analyze_features($dba);
		my $other_features = $dba_hash->{otherfeatures}{$dba->species()};
		if (defined $other_features) {
		  $self->{logger}->info("Processing " . $dba->species() . " otherfeatures annotation");
		  $md->{features} = {%{$md->{features}}, %{$self->{annotation_analyzer}->analyze_features($other_features)}};
		}
		# variation
		my $variation = $dba_hash->{variation}{$dba->species()};
		if (defined $variation) {
		  $self->{logger}->info("Processing " . $dba->species() . " variation annotation");
		  $md->{variation} = $self->{annotation_analyzer}->analyze_variation($variation);
		}
		# BAM
		$md->{bam} = $self->{annotation_analyzer}->analyze_tracks($md->{species}, $md->{division});
		# compara
		(my $compara_div = lc $md->{division}) =~ s/ensembl//;
		my $compara = $dba_hash->{compara}{$compara_div};
		if (defined $compara) {
		  $self->{logger}->info("Processing " . $dba->species() . " compara annotation");
		  $md->{compara} = $self->{annotation_analyzer}->analyze_compara($compara, $dba);
		}
		if (defined $pan_species->{$dba->species()}) {
		  $md->{pan_species} = 1;
		} else {
		  $md->{pan_species} = 0;
		}
	  } ## end if (defined $self->{annotation_analyzer...})
	  push @{$metadata->{genome}}, $md;
	};
	if ($@) {
	  warning "Could not get metadata for species " . $dba->species() . ":" . $@;
	}
  } ## end for my $dba (values %{$dba_hash...})

  if (defined $metadata->{genome}) {
	$metadata->{genome} = [sort { $a->{division} cmp $b->{division} or $a->{name} cmp $b->{name} } @{$metadata->{genome}}];
  }
  return $metadata;
} ## end sub process_metadata

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
