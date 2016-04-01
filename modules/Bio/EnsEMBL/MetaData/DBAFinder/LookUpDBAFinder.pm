=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::DBAFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

Implementation using Bio::EnsEMBL::MetaData::DBAFinder

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBAFinder::LookUpDBAFinder;
use base qw( Bio::EnsEMBL::MetaData::DBAFinder );
use Bio::EnsEMBL::LookUp;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use strict;
use warnings;

=head1 SUBROUTINES/METHODS
=head2 new
Arg         : [-USER] user
Arg         : [-PASS] password
Arg         : [-HOST] host to load from
Arg         : [-PORT] port to connect to
Description : Create a new object
Returntype  : Bio::EnsEMBL::MetaData::DBAFinder::LookUpDBAFinder
=cut
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
=head2 get_dbas
  Description: Find DBAs to work on
  Returntype : Arrayref of Bio::EnsEMBL::DBSQL::DBAdaptor
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub get_dbas {
  my ($self) = @_;
  if (!defined $self->{dbas}) {
	$self->{dbas} = $self->helper()->get_all_DBAdaptors();
  }
  return $self->{dbas};
}

1;

