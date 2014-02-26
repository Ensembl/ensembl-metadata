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

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo

=head1 SYNOPSIS

	  my $compara_info =
		Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo->new(
								   -DBNAME => $compara->dbc()->dbname(),
								   -DIVISION => $division,
								   -METHOD   => $method,
								   -GENOMES  => [$genome1, $genome2]);

=head1 DESCRIPTION

Object encapsulating information about a particular compara analysis and the genomes it involves

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo;
use Log::Log4perl qw(get_logger);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use strict;
use warnings;

=head1 CONSTRUCTOR
=head2 new
  Arg [-DIVISION]  : 
       string - Compara division e.g. plants, pan_homology
  Arg [-METHOD]    : 
       string - compara method e.g. PROTEIN_TREES, LASTZ_NET
  Arg [-DBNAME] : 
       string - name of the compara database in which the analysis can be found
  Arg [-GENOMES]  : 
       arrayref - list of genomes involved in analysis

  Example    : $info = Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo->new(...);
  Description: Creates a new info object
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut
sub new {
  my ($proto, @args) = @_;
  my $class = ref($proto) || $proto;
  my $self = bless({}, $class);
  $self->{logger} = get_logger();
  ($self->{division}, $self->{method},
   $self->{dbname},   $self->{genomes}
  ) = rearrange(['DIVISION', 'METHOD', 'DBNAME', 'GENOMES'], @args);
  return $self;
}


=head1 ATTRIBUTE METHODS
=head2 dbname
  Arg        : (optional) dbname to set
  Description: Gets/sets name of compara database
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub dbname {
  my ($self, $arg) = @_;
  $self->{dbname} = $arg if (defined $arg);
  return $self->{dbname};
}

=head2 method
  Arg        : (optional) method to set
  Description: Gets/sets name of compara method
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub method {
  my ($self, $arg) = @_;
  $self->{method} = $arg if (defined $arg);
  return $self->{method};
}

=head2 division
  Arg        : (optional) division to set
  Description: Gets/sets Ensembl compara division
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub division {
  my ($self, $arg) = @_;
  $self->{division} = $arg if (defined $arg);
  return $self->{division};
}

=head2 genomes
  Arg        : (optional) genomes to set
  Description: Gets/sets arrayref of genomes 
  Returntype : arrayref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub genomes {
  my ($self, $arg) = @_;
  $self->{genomes} = $arg if (defined $arg);
  return $self->{genomes};
}

=head1 UTILITY METHODS
=head2 is_pan_compara
  Arg        : (optional) 1/0 to set 
  Description: Boolean-style method, returns 1 if analysis is part of the pan compara, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub is_pan_compara {
  my ($self) = @_;
  return $self->{division} eq 'pan_homology'?1:0;
}

=head2 is_peptide_compara
  Arg        : (optional) 1/0 to set 
  Description: Boolean-style method, returns 1 if analysis is part of a peptide compara, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub is_peptide_compara {
  my ($self) = @_;
  return ($self->{division} ne 'pan_homology' &&
	$self->{method} eq 'PROTEIN_TREES')?1:0;
}

=head2 is_dna_compara
  Arg        : (optional) 1/0 to set 
  Description: Boolean-style method, returns 1 if analysis is part of a DNA compara, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub is_dna_compara {
  my ($self) = @_;
  return ($self->{method} eq 'TRANSLATED_BLAT_NET' ||
	$self->{method} eq 'LASTZ_NET' ||
	$self->{method} eq 'BLASTZ_NET')?1:0;
}

=head2 to_hash
  Description: Render compara as plain hash suitable for export as JSON/XML
  Returntype : Hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub to_hash {
  my ($in) = @_;
  my $out = {method             => $in->{method},
			 division           => $in->{division},
			 dbname             => $in->{dbname},
			 is_pan_compara     => $in->is_pan_compara(),
			 is_peptide_compara => $in->is_peptide_compara(),
			 is_dna_compara     => $in->is_dna_compara(),};
  $out->{genomes} = [];
  for my $genome (@{$in->genomes()}) {
	push @{$out->{genomes}}, $genome->species();
  }
  return $out;
}

=head1 INTERNAL METHODS
=head2 dbID
  Arg        : (optional) dbID to set set
  Description: Gets/sets internal compara_analysis_id used as database primary key
  Returntype : dbID string
  Exceptions : none
  Caller     : Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor
  Status     : Stable
=cut

sub dbID {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{dbID} = $arg;
  }
  return $self->{dbID};
}

=head2 adaptor
  Arg        : (optional) adaptor to set set
  Description: Gets/sets GenomeInfoAdaptor
  Returntype : Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut
sub adaptor {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{adaptor} = $arg;
  }
  return $self->{adaptor};
}

1;
