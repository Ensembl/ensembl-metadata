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

package Bio::EnsEMBL::MetaData::DBAFinder::EnaDBAFinder;
use base qw( Bio::EnsEMBL::MetaData::DBAFinder );
use Bio::EnsEMBL::LookUp;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  my ($url, $host, $port, $user, $pass, $pattern, $nocache) =
	rearrange(
			  ['URL',  'HOST',    'PORT', 'USER',
			   'PASS', 'PATTERN', 'NO_CACHE'],
			  @args);
  if (defined $url) {
	$self->{helper} = Bio::EnsEMBL::LookUp->new(-URL => $url);
  }
  else {
	Bio::EnsEMBL::LookUp->register_all_dbs($host, $port, $user, $pass,
										   $pattern);
	$self->{helper} = Bio::EnsEMBL::LookUp->new(-NO_CACHE => $nocache);
  }
  return $self;
}

sub helper {
  my ($self) = @_;
  return $self->{helper};
}

sub get_dbas {
  my ($self) = @_;
  if (!defined $self->{dbas}) {
	$self->{dbas} = $self->helper()->get_all_DBAdaptors();
  }
  return $self->{dbas};
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::MetaData::DBAFinder::EnaDBAFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation using the ENA helper to build a list of DBAs

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
