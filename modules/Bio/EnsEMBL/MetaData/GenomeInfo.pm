
=head1 LICENSE

Copyright [1999-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::MetaData::GenomeInfo

=head1 SYNOPSIS

  my $genome = Bio::EnsEMBL::MetaData::GenomeInfo->new(
	  -species    => $dba->species(),
	  -species_id => $dba->species_id(),
	  -division   => $meta->get_division() || 'EnsemblVertebrates',
	  -dbname     => $dbname);
	  
  print Dumper($genome->to_hash());

=head1 DESCRIPTION

Object encapsulating meta information about a genome in Ensembl Genomes. 

Can be used to render information about a genome e.g.

print $genome->name()." (".$genome->species.")\n";
print "Sequences: ".scalar(@{$genome->sequences()})."\n";
if($genome->has_variations()) {
	print "Variations: \n";
	# variations is a hash with type as the key
	while(my ($type,$value) = each %{$genome->variations()}) {
		print "- $type\n";
	}
}
print "Compara analyses: ".scalar(@{$genome->compara()})."\n";

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::BaseInfo
Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
Bio::EnsEMBL::MetaData::GenomeOrganismInfo
Bio::EnsEMBL::MetaData::GenomeComparaInfo
Bio::EnsEMBL::MetaData::DataReleaseInfo
Bio::EnsEMBL::MetaData::DatabaseInfo
Bio::EnsEMBL::MetaData::EventInfo
Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor

=head1 AUTHOR

Dan Staines

=cut

use strict;
use warnings;

package Bio::EnsEMBL::MetaData::GenomeInfo;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::MetaData::DataReleaseInfo;
use Bio::EnsEMBL::MetaData::GenomeAssemblyInfo;
use Bio::EnsEMBL::MetaData::GenomeOrganismInfo;

=head1 CONSTRUCTOR
=head2 new
  Arg [-DISPLAY_NAME]  : 
       string - human readable version of the name of the genome
  Arg [-SCIENTIFIC_NAME]  : 
       string - scientific name of the genome
  Arg [-NAME]    : 
       string - computable version of the name of the genome (lower case, no spaces)
  Arg [-DBNAME] : 
       string - name of the core database in which the genome can be found
  Arg [-SPECIES_ID]  : 
       int - identifier of the species within the core database for this genome
  Arg [-TAXONOMY_ID] :
        string - NCBI taxonomy identifier
  Arg [-SPECIES_TAXONOMY_ID] :
        string - NCBI taxonomy identifier of species to which this genome belongs
  Arg [-ASSEMBLY_NAME] :
        string - name of the assembly
  Arg [-ASSEMBLY_ID] :
        string - INSDC assembly accession
  Arg [-ASSEMBLY_LEVEL] :
        string - highest assembly level (chromosome, supercontig etc.)
  Arg [-GENEBUILD]:
        string - identifier for genebuild
  Arg [-DIVISION]:
        string - name of Ensembl Genomes division (e.g. EnsemblBacteria, EnsemblPlants)
  Arg [-STRAIN]:
        string - name of strain to which genome belongs
  Arg [-SEROTYPE]:
        string - name of serotype to which genome belongs
  Arg [-REFERENCE]:
        string - name of the reference species for this strain

  Example    : $info = Bio::EnsEMBL::MetaData::GenomeInfo->new(...);
  Description: Creates a new info object
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  my ( $name,                $display_name,  
       $scientific_name, $url_name, $dbname,              
       $species_id,    $taxonomy_id,
       $species_taxonomy_id, $assembly_name, 
       $assembly_id,
       $assembly_default,    $assembly_ucsc,
       $assembly_level,      $strain,        $serotype,
       $reference);
  ( $name,                $display_name,      
    $scientific_name, $url_name,
    $dbname,              $species_id,        $taxonomy_id,
    $species_taxonomy_id, $assembly_name,     $assembly_id,
    $assembly_default,    $assembly_ucsc,
    $assembly_level,      $self->{genebuild}, $self->{division},
    $strain,              $serotype,          $reference,
    $self->{assembly},    $self->{organism},          $self->{data_release} )
    = rearrange( [ 'NAME',                'DISPLAY_NAME',
                   'SCIENTIFIC_NAME',     'URL_NAME', 'DBNAME',
                   'SPECIES_ID',          'TAXONOMY_ID',
                   'SPECIES_TAXONOMY_ID', 'ASSEMBLY_NAME',
                   'ASSEMBLY_ACCESSION',  'ASSEMBLY_DEFAULT',    
		   'ASSEMBLY_UCSC',       'ASSEMBLY_LEVEL',
                   'GENEBUILD',           'DIVISION',
                   'STRAIN',              'SEROTYPE',
                   'REFERENCE',        'ASSEMBLY',
                   'ORGANISM',            'DATA_RELEASE' ],
                 @args );

  if ( defined $dbname ) {
    $self->add_database( $dbname, $species_id );
  }

  if ( !defined $self->assembly() ) {
    my $ass = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(
                       -ASSEMBLY_NAME       => $assembly_name,
                       -ASSEMBLY_ACCESSION  => $assembly_id,
                       -ASSEMBLY_DEFAULT    => $assembly_default,
                       -ASSEMBLY_UCSC       => $assembly_ucsc,
                       -ASSEMBLY_LEVEL      => $assembly_level );
    $ass->adaptor( $self->adaptor() ) if defined $self->adaptor();
    $self->assembly($ass);
  }
  
    if ( !defined $self->{organism} ) {
    my $organism = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(
                       -NAME                => $name,
                       -DISPLAY_NAME        => $display_name,
                       -SCIENTIFIC_NAME     => $scientific_name,
                       -URL_NAME            => $url_name,
                       -TAXONOMY_ID         => $taxonomy_id,
                       -SPECIES_TAXONOMY_ID => $species_taxonomy_id,
                       -STRAIN              => $strain,
                       -SEROTYPE            => $serotype,
                       -REFERENCE           => $reference );
    $organism->adaptor( $self->adaptor() ) if defined $self->adaptor();
    $self->organism($organism);
  }
  return $self;
} ## end sub new

=head1 ATTRIBUTE METHODS

=head2 dbname
  Description: Gets name of core database from which genome comes
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub dbname {
  my ($self) = @_;
  return $self->_get_core()->dbname();
}

=head2 species_id
  Description: Gets species_id of genome within core database
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub species_id {
  my ($self) = @_;
  return $self->_get_core()->species_id();
}

=head2 databases
  Arg        : (optional) Arrayref of DatabaseInfo objects to set
  Description: Gets/sets databases associated with the genome
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::DatabaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub databases {
  my ( $self, $databases ) = @_;
  if ( defined $databases ) {
    $self->{databases} = $databases;
  }
  $self->_load_child( 'databases', '_fetch_databases' );
  return $self->{databases};
}

=head2 data_release
  Arg        : (optional) data_release object to set
  Description: Gets/sets data_release to which genome belongs
  Returntype : Bio::EnsEMBL::MetaData::DataReleaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub data_release {
  my ( $self, $data_release ) = @_;
  $self->{data_release} = $data_release if ( defined $data_release );
  $self->_load_child( 'data_release', '_fetch_data_release' );
  return $self->{data_release};
}

=head2 organism
  Arg        : (optional) organism object to set
  Description: Gets/sets organism to which genome belongs
  Returntype : Bio::EnsEMBL::MetaData::GenomeOrganismInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub organism {
  my ( $self, $organism ) = @_;
  $self->{organism} = $organism if ( defined $organism );
  $self->_load_child( 'organism', '_fetch_organism' );
  return $self->{organism};
}

=head2 display_name
  Description: Gets readable name
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub display_name {
  my ( $self, $name ) = @_;
  return $self->organism()->display_name($name);
}

=head2 url_name
  Description: Gets name for use in URL
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub url_name {
  my ( $self, $name ) = @_;
  return $self->organism()->url_name($name);
}

=head2 scientific_name
  Description: Gets readable name
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub scientific_name {
  my ( $self, $name ) = @_;
  return $self->organism()->scientific_name($name);
}

=head2 strain
  Description: Gets/sets strain of genome
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub strain {
  my ($self) = @_;
  return $self->organism()->strain();
}

=head2 serotype
  Description: Gets serotype
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub serotype {
  my ($self) = @_;
  return $self->organism()->serotype();
}

=head2 name
  Description: Gets unique, compute-safe name for genome
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub name {
  my ($self) = @_;
  return $self->organism()->name();
}

=head2 taxonomy_id
  Description: Gets NCBI taxonomy ID
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub taxonomy_id {
  my ($self) = @_;
  return $self->organism()->taxonomy_id();
}

=head2 species_taxonomy_id
  Description: Gets NCBI taxonomy ID of species to which this belongs
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub species_taxonomy_id {
  my ($self) = @_;
  return $self->organism()->species_taxonomy_id();
}

=head2 assembly
  Arg        : (optional) assembly to set
  Description: Gets/sets assembly object
  Returntype : Bio::EnsEMBL::MetaData::GenomeAssemblyInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly {
  my ( $self, $assembly ) = @_;
  $self->{assembly} = $assembly if ( defined $assembly );
  $self->_load_child( 'assembly', '_fetch_assembly' );
  return $self->{assembly};
}

=head2 assembly_name
  Description: Gets name of assembly
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_name {
  my ($self) = @_;
  return $self->assembly()->assembly_name();
}

=head2 assembly_accession
  Description: Gets INSDC accession for assembly
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_accession {
  my ($self) = @_;
  return $self->assembly()->assembly_accession();
}

=head2 assembly_default
  Description: Gets default name of assembly
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_default {
  my ($self) = @_;
  return $self->assembly()->assembly_default();
}

=head2 assembly_ucsc
  Description: Gets UCSC alias for assembly
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_ucsc {
  my ($self) = @_;
  return $self->assembly()->assembly_ucsc();
}

=head2 assembly_level
  Description: Gets highest level of assembly (chromosome, supercontig etc.)
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_level {
  my ($self) = @_;
  return $self->assembly()->assembly_level();
}

=head2 genebuild
  Arg        : (optional) genebuild to set
  Description: Gets/sets identifier for genebuild
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub genebuild {
  my ( $self, $genebuild ) = @_;
  $self->{genebuild} = $genebuild if ( defined $genebuild );
  return $self->{genebuild};
}

=head2 division
  Arg        : (optional) division to set
  Description: Gets/sets Ensembl Genomes division
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub division {
  my ( $self, $division ) = @_;
  $self->{division} = $division if ( defined $division );
  return $self->{division};
}

=head2 reference
  Arg        : (optional) value of reference
  Description: Gets/sets whether this strain has a reference
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub reference {
  my ( $self, $is_ref ) = @_;
  return $self->organism()->reference($is_ref);
}

=head2 db_size
  Arg        : (optional) db_size to set
  Description: Gets/sets size of database containing core
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub db_size {
  my ( $self, $arg ) = @_;
  $self->{db_size} = $arg if ( defined $arg );
  return $self->{db_size};
}

=head2 base_count
  Description: Gets total number of bases in assembled genome
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub base_count {
  my ($self) = @_;
  return $self->assembly()->base_count();
}

=head2 aliases
  Description: Gets aliases by which the genome is also known 
  Returntype : Arrayref of aliases
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub aliases {
  my ($self) = @_;
  return $self->organism()->aliases();
}

=head2 compara
  Arg        : (optional) arrayref of GenomeComparaInfo objects to set
  Description: Gets/sets GenomeComparaInfo describing comparative analyses applied to the genome
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub compara {
  my ( $self, $compara ) = @_;
  if ( defined $compara ) {
    $self->{compara}               = $compara;
    $self->{has_peptide_compara}   = undef;
    $self->{has_synteny}           = undef;
    $self->{has_genome_alignments} = undef;
    $self->{has_pan_compara}       = undef;
  }
  $self->_load_child( 'compara', '_fetch_comparas' );
  return $self->{compara};
}

=head2 sequences
  Description: Gets array of hashrefs describing sequences from the assembly. Elements are hashrefs with name and acc as keys
  Returntype : Arrayref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub sequences {
  my ($self) = @_;
  return $self->assembly()->sequences();
}

=head2 publications
  Description: Gets PubMed IDs for publications associated with the genome
  Returntype : Arrayref of PubMed IDs
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub publications {
  my ($self) = @_;
  return $self->organism()->publications();
}

=head2 variations
  Arg        : (optional) variations to set
  Description: Gets/sets variations associated with genomes as hashref 
  			   (variations,structural variations,genotypes,phenotypes), 
  			   further broken down into counts by type/source
  Returntype : Arrayref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub variations {
  my ( $self, $variations ) = @_;
  if ( defined $variations ) {
    $self->{variations}     = $variations;
    $self->{has_variations} = undef;
  }
  $self->_load_child( 'variations', '_fetch_variations' );
  return $self->{variations};
}

=head2 features
  Arg        : (optional) features to set
  Description: Gets/sets general genomic features associated with the genome as hashref
  			   keyed by type (e.g. repeatFeatures,simpleFeatures), further broken down into
  			   counts by analysis
  Returntype : Hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub features {
  my ( $self, $features ) = @_;
  if ( defined $features ) {
    $self->{features} = $features;
  }
  $self->_load_child( 'features', '_fetch_features' );
  return $self->{features};
}

=head2 annotations
  Arg        : (optional) annotations to set
  Description: Gets/sets summary information about gene annotation as hashref, with
  			   annotation type as key value
  Returntype : hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub annotations {
  my ( $self, $annotation ) = @_;
  if ( defined $annotation ) {
    $self->{annotations} = $annotation;
  }
  $self->_load_child( 'annotations', '_fetch_annotations' );
  return $self->{annotations};
}

=head2 other_alignments
  Arg        : (optional) other alignments to set
  Description: Gets/sets other alignments as hashref, keyed by type (dnaAlignFeatures,proteinAlignFeatures)
  			   with values as logic_name-count pairs 
  Returntype : Hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub other_alignments {
  my ( $self, $other_alignments ) = @_;
  if ( defined $other_alignments ) {
    $self->{other_alignments}     = $other_alignments;
    $self->{has_other_alignments} = undef;
  }
  $self->_load_child( 'other_alignments', '_fetch_other_alignments' );
  return $self->{other_alignments} || 0;
}

=head1 utility methods
=head2 has_variations
  Arg        : (optional) 1/0 to set if genome has variation
  Description: Boolean-style method, returns 1 if genome has variation, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_variations {
  my ( $self, $arg ) = @_;
  if ( defined $arg ) {
    $self->{has_variations} = $arg;
  }
  elsif ( !defined( $self->{has_variations} ) && defined $self->variations() ) {
    $self->{has_variations} = $self->count_variation() > 0 ? 1 : 0;
  }
  return $self->{has_variations} || 0;
}

=head2 has_microarray
  Arg        : (optional) 1/0 to set if genome has microarray
  Description: Boolean-style method, returns 1 if genome has microarrays, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_microarray {
  my ( $self, $arg ) = @_;
  if ( defined $arg ) {
    $self->{has_microarray} = $arg;
  }
  elsif ( !defined( $self->{has_microarray} ) && defined $self->databases() ) {
    $self->{has_microarray} = grep { $_->type() eq 'funcgen' } @{ $self->databases() };
  }
  return $self->{has_microarray} || 0;
}

=head2 has_genome_alignments
  Arg        : (optional) 1/0 to set if genome has genome alignments
  Description: Boolean-style method, returns 1 if genome has genome alignments, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_genome_alignments {
  my ( $self, $arg ) = @_;
  if ( defined $arg ) {
    $self->{has_genome_alignments} = $arg;
  }
  elsif ( !defined( $self->{has_genome_alignments} ) &&
          defined $self->compara() )
  {
    $self->{has_genome_alignments} = 0;
    for my $compara ( @{ $self->compara() } ) {
      if ( $compara->is_dna_compara() ) {
        $self->{has_genome_alignments} = 1;
        last;
      }
    }
  }
  return $self->{has_genome_alignments} || 0;
}

=head2 has_synteny
  Arg        : (optional) 1/0 to set if genome has synteny
  Description: Boolean-style method, returns 1 if genome has synteny, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_synteny {
  my ( $self, $arg ) = @_;
  if ( defined $arg ) {
    $self->{has_synteny} = $arg;
  }
  elsif ( !defined( $self->{has_synteny} ) && defined $self->compara() ) {
    $self->{has_synteny} = 0;
    for my $compara ( @{ $self->compara() } ) {
      if ( $compara->is_synteny() ) {
        $self->{has_synteny} = 1;
        last;
      }
    }
  }
  return $self->{has_synteny} || 0;
}

=head2 has_peptide_compara
  Arg        : (optional) 1/0 to set if genome has peptide compara
  Description: Boolean-style method, returns 1 if genome has peptide, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_peptide_compara {
  my ( $self, $arg ) = @_;
  if ( defined $arg ) {
    $self->{has_peptide_compara} = $arg;
  }
  elsif ( !defined( $self->{has_peptide_compara} ) && defined $self->compara() )
  {
    $self->{has_peptide_compara} = 0;
    for my $compara ( @{ $self->compara() } ) {
      if ( $compara->is_peptide_compara() && !$compara->is_pan_compara() ) {
        $self->{has_peptide_compara} = 1;
        last;
      }
    }
  }
  return $self->{has_peptide_compara} || 0;
}

=head2 has_pan_compara
  Arg        : (optional) 1/0 to set if genome is included in pan compara
  Description: Boolean-style method, returns 1 if genome is in pan compara, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_pan_compara {
  my ( $self, $arg ) = @_;
  if ( defined $arg ) {
    $self->{has_pan_compara} = $arg;
  }
  elsif ( !defined( $self->{has_pan_compara} ) && defined $self->compara() ) {
    $self->{has_pan_compara} = 0;
    for my $compara ( @{ $self->compara() } ) {
      if ( $compara->is_pan_compara() ) {
        $self->{has_pan_compara} = 1;
        last;
      }
    }
  }
  return $self->{has_pan_compara} || 0;
}

=head2 has_other_alignments
  Arg        : (optional) 1/0 to set if genome has other alignments
  Description: Boolean-style method, returns 1 if genome has other alignments, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_other_alignments {
  my ( $self, $arg ) = @_;
  if ( defined $arg ) {
    $self->{has_other_alignments} = $arg;
  }
  elsif ( !defined( $self->{has_other_alignments} ) ) {
    $self->{has_other_alignments} = $self->count_alignments() > 0 ? 1 : 0;
  }
  return $self->{has_other_alignments} || 0;
}

=head2 count_variation
  Description: Returns total number of variations and structural variations mapped to genome
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub count_variation {
  my ($self) = @_;
  return $self->count_hash_values( $self->{variations}{variations} ) +
    $self->count_hash_values( $self->{variations}{structural_variations} );
}

=head2 count_alignments
  Description: Returns total number of alignments to genome
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub count_alignments {
  my ($self) = @_;
  return $self->count_hash_values( $self->{other_alignments}{bam} ) +
    $self->count_hash_values( $self->{other_alignments}{proteinAlignFeatures} )
    + $self->count_hash_values( $self->{other_alignments}{dnaAlignFeatures} );
}

=head2 get_uniprot_coverage
  Description: Get % of protein coding genes with a UniProt cross-reference
  Returntype : uniprot coverage as percentage
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub get_uniprot_coverage {
  my ($self) = @_;
  return 100.0*
    ( $self->annotations()->{nProteinCodingUniProtKB} )/
    $self->annotations()->{nProteinCoding};
}

=head2 add_database
  Arg        : Name of database
  Arg        : (Optional) species_id (defaults to 1)
  Description: Add a database associated with this genome
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub add_database {
  my ( $self, $dbname, $species_id ) = @_;
  $self->{species_id} ||= 1;
  push @{ $self->{databases} },
    Bio::EnsEMBL::MetaData::DatabaseInfo->new( -SUBJECT    => $self,
                                               -DBNAME     => $dbname,
                                               -SPECIES_ID => $species_id );
  return;
}

=head2 to_string
  Description: Render genome as string for display
  Returntype : String
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub to_string {
  my ($self) = @_;
  return
    join( ':',
          ( $self->dbID() || '-' ), $self->name(),
          $self->dbname(), $self->species_id() );
}

=head2 to_hash
  Description: Render genome as plain hash suitable for export as JSON/XML
  Argument   : (optional) if set to 1, force expansion of children
  Returntype : Hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub to_hash {
  my ( $in, $keen ) = @_;
  my $out;
  my $type = ref $in;
  if ( defined $keen &&
       $keen == 1 &&
       $type =~ m/Bio::EnsEMBL::MetaData::[A-z]+Info/ )
  {
    $in->_preload();
  }
  if ( $type eq 'ARRAY' ) {
    $out = [];
    for my $item ( @{$in} ) {
      push @{$out}, to_hash( $item, $keen );
    }
  }
  elsif ( $type eq 'HASH' || $type eq 'Bio::EnsEMBL::MetaData::GenomeInfo' ) {
    $out = {};
    while ( my ( $key, $val ) = each %$in ) {
      if ( $key ne 'dbID' && $key ne 'adaptor' && $key ne 'logger' ) {

# deal with keys starting with numbers, which are not valid element names in XML
        if ( $key =~ m/^[0-9].*/ ) {
          $key = '_' . $key;
        }
        $out->{$key} = to_hash( $val, $keen );
      }

    }
  }
  elsif ( $type =~ m/Bio::EnsEMBL::MetaData::[A-z]+Info/ ) {
    $out = $in->to_hash($keen);
  }
  else {
    $out = $in;
  }
  if ( defined $keen &&
       $keen == 1 &&
       $type =~ m/Bio::EnsEMBL::MetaData::[A-z]+Info/ )
  {
    $in->_preload();
  }
  return $out;
} ## end sub to_hash

=head1 INTERNAL METHODS
=head2 _get_core
  Description: Convenience method to find core database
  Returntype : DatabaseInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _get_core {
  my ($self) = @_;
  if ( !defined $self->{core} ) {
    ( $self->{core} ) = grep { $_->type() eq 'core' } @{ $self->databases() };
  }
  return $self->{core};
}

=head2 count_hash_values
  Description: Sums values found in hash
  Arg		 : hashref
  Returntype : integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub count_hash_values {
  my ( $self, $hash ) = @_;
  my $tot = 0;
  if ( defined $hash ) {
    for my $v ( values %{$hash} ) {
      $tot += $v;
    }
  }
  return $tot;
}

=head2 count_hash_lengths
  Description: Sums sizes of arrays found in hash as values
  Arg		 : hashref
  Returntype : integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub count_hash_lengths {
  my ( $self, $hash ) = @_;
  my $tot = 0;
  if ( defined $hash ) {
    for my $v ( values %{$hash} ) {
      $tot += scalar(@$v);
    }
  }
  return $tot;
}

=head2 dbID
  Arg        : (optional) dbID to set set
  Description: Gets/sets internal genome_id used as database primary key
  Returntype : dbID string
  Exceptions : none
  Caller     : Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
  Status     : Stable
=cut

sub dbID {
  my ( $self, $id ) = @_;
  $self->{dbID} = $id if ( defined $id );
  return $self->{dbID};
}

=head2 adaptor
  Arg        : (optional) adaptor to set set
  Description: Gets/sets GenomeInfoAdaptor
  Returntype : Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut

sub adaptor {
  my ( $self, $adaptor ) = @_;
  $self->{adaptor} = $adaptor if ( defined $adaptor );
  return $self->{adaptor};
}

=head2 _preload
  Description: Ensure all children are loaded (used for hash transformation)
  Returntype : none
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut

sub _preload {
  my ($self) = @_;
  $self->annotations();
  $self->compara();
  $self->features();
  $self->other_alignments();
  $self->variations();
  return;
}

=head2 _preload
  Description: Remove all children (used after hash transformation to ensure object is minimised)
  Returntype : none
  Exceptions : none
  Caller     : dump_metadata.pl
  Status     : Stable
=cut

sub _unload {
  my ($self) = @_;
  $self->{annotations}      = undef;
  $self->{compara}          = undef;
  $self->{features}         = undef;
  $self->{other_alignments} = undef;
  $self->{variations}       = undef;
  return;
}

1;
