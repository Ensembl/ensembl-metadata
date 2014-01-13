=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
=cut

package Bio::EnsEMBL::Utils::MetaData::DBAFinder::RegistryDBAFinder;
use base qw( Bio::EnsEMBL::Utils::MetaData::DBAFinder );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  ($self->{regfile}) = rearrange(['REGISTRY'], @args);
  $self->{registry} ||= 'Bio::EnsEMBL::Registry';
  if (defined $self->{regfile}) {
	$self->{registry}->load_all($self->{regfile});
  }
  return $self;
}

sub registry {
  my ($self) = @_;
  return $self->{registry};
}

sub get_dbas {
  my ($self) = @_;
  if (!defined $self->{dbas}) {
	$self->{dbas} = Bio::EnsEMBL::Registry->get_all_DBAdaptors();
  }
  return $self->{dbas};
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::DBAFinder::RegistryDBAFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation using a registry to build a list of DBAs

=head1 SUBROUTINES/METHODS

=head2 new

=head2 get_dbas
Description : Return list of DBAs to work on

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
