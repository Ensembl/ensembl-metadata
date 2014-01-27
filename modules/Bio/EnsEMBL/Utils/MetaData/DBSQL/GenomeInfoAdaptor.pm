
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

package Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;

use strict;
use warnings;
use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Data::Dumper;

sub new {
  my ($proto, @args) = @_;
  my $self = bless {}, $proto;
  ($self->{dbc}) = rearrange(['DBC'],@args);
  return $self;
}

sub store {
  my ($self, $genome) = @_;
  croak("Genome has already been stored") if defined $genome->dbID();
  $self->{dbc}->sql_helper()->execute_update(
	-SQL =>
q/insert into genome(name,strain,serotype,division,taxonomy_id,
assembly_id,assembly_name,assembly_level,base_count,
genebuild,dbname,species_id)
		values(?,?,?,?,?,?,?,?,?,?,?,?)/,
	-PARAMS => [$genome->name(),          $genome->strain(),
				$genome->serotype(),      $genome->division(),
				$genome->taxonomy_id(),   $genome->assembly_id(),
				$genome->assembly_name(), $genome->assembly_level(),
				$genome->base_count(),    $genome->genebuild(),
				$genome->dbname(),        $genome->species_id()],
	-CALLBACK => sub {
	  my ($sth, $dbh, $rv) = @_;
	  $genome->dbID($dbh->{mysql_insertid});
	});
  $genome->adaptor($self);
  return;
}

1;
