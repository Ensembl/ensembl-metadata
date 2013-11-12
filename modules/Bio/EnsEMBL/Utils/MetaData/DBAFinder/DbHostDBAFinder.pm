
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

package Bio::EnsEMBL::Utils::MetaData::DBAFinder::DbHostDBAFinder;
use base
  qw( Bio::EnsEMBL::Utils::MetaData::DBAFinder::RegistryDBAFinder );
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  # populate the registry
  $self->registry()->load_registry_from_db(@args);
  $self->registry()->set_disconnect_when_inactive(1);
  return $self;
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::DBAFinder::DbHostDBAFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation using a registry built from a specified server to build a list of DBAs

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
