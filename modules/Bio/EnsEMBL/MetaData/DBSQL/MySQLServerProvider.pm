
=head1 LICENSE

Copyright [2009-2022] EMBL-European Bioinformatics Institute

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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::MetaData::DBSQL::MySQLServerProvider

=head1 SYNOPSIS

  my $provider = Bio::EnsEMBL::MetaData::DBSQL::MySQLServerProvider->new();
  my $args = $provider->args_for_genome($info);
  my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%$args);

=head1 DESCRIPTION

Provides public DB argument for a supplied info object or division

=cut

package Bio::EnsEMBL::MetaData::DBSQL::MySQLServerProvider;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::PublicMySQLServer qw(eg_args e_args);

=head1 CONSTRUCTOR
=head2 new 
  Description: Creates a new provider object
  Returntype : Bio::EnsEMBL::MetaData::DBSQL::MySQLServerProvider
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub new {
  my ( $proto, @args ) = @_;
  my $class = ref($proto) || $proto;
  my $self = bless( {}, $class );
  return $self;
}

=head1 METHODS
=head2 args_for_genome
  Description: Return the host arguments to build a DBAdaptor for a supplied info object
  Argument   : Bio::EnsEMBL::MetaData::GenomeInfo
  Returntype : Hashref
  Exceptions : none
  Caller     : 
  Status     : Stable
=cut
sub args_for_genome {
  my ($self, $info) = @_;
  return $self->args_for_division($info->division());
}

=head2 args_for_division
  Description: Return the host arguments to build a DBAdaptor for a supplied division
  Argument   : String
  Returntype : Hashref
  Exceptions : none
  Caller     : 
  Status     : Stable
=cut
sub args_for_division {
  my ($self, $division) = @_;
  if($division eq 'EnsemblVertebrates') {
    return e_args();    
  } else {
    return eg_args();
  }
  return;
}

1;

