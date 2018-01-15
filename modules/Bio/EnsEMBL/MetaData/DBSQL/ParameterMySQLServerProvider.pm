
=head1 LICENSE

Copyright [2009-2018] EMBL-European Bioinformatics Institute

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

Provides specified DB argument for a supplied info object or division.

Used internally by Bio::EnsEMBL::LookUp::RemoteLookUp

=cut

package Bio::EnsEMBL::MetaData::DBSQL::ParameterMySQLServerProvider;

use strict;
use warnings;

use base 'Bio::EnsEMBL::MetaData::DBSQL::MySQLServerProvider';

use Bio::EnsEMBL::Utils::Argument qw/rearrange/;

=head1 CONSTRUCTOR
=head2 new 
  Description: Creates a new provider object which returns the supplied arguments
  Arg [-HOST]       : Host containing DBAdaptors
  Arg [-PORT]       : Port  for DBAdaptors
  Arg [-USER]       : User for DBAdaptors
  Arg [-PASS]       : Password for DBAdaptors
  Returntype : Bio::EnsEMBL::MetaData::DBSQL::MySQLServerProvider
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  ( $self->{user}, $self->{pass}, $self->{host}, $self->{port} ) =
    rearrange( [ 'USER', 'PASS', 'HOST', 'PORT' ], @args );
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
  my ( $self, $info ) = @_;
  return $self->args_for_division( $info->division() );
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
  my ( $self, $division ) = @_;
  return { -USER => $self->{user},
           -HOST => $self->{host},
           -PORT => $self->{port},
           -PASS => $self->{pass} };
}

1;

