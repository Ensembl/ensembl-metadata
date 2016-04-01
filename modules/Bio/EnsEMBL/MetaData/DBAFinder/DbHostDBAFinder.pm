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

Bio::EnsEMBL::MetaData::DBAFinder::DbHostDBAFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

Implementation retrieving DBAs from specified host

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBAFinder::DbHostDBAFinder;
use base
  qw( Bio::EnsEMBL::MetaData::DBAFinder::RegistryDBAFinder );
use strict;
use warnings;

=head1 SUBROUTINES/METHODS
=head2 new
Arg         : [-USER] user
Arg         : [-PASS] password
Arg         : [-HOST] host to load from
Arg         : [-PORT] port to connect to
Description : Create a new object
Returntype  : Bio::EnsEMBL::MetaData::DBAFinder::DbHostDBAFinder
=cut
sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  if(!defined $self->{regfile}) {
      $self->registry()->load_registry_from_db(@args);
      $self->registry()->set_disconnect_when_inactive(1);
  }
  return $self;
}

1;

