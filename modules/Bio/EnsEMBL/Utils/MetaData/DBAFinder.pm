
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

package Bio::EnsEMBL::Utils::MetaData::DBAFinder;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use strict;
use warnings;

sub new {
    my $caller = shift;
    my $class = ref($caller) || $caller;
    my $self = bless( {}, $class );
    return $self;
}

sub get_dbas {
    my ($self) = @_;
    throw "Unimplemented subroutine get_dbas() in "
      . ref($self)
      . ". Please implement";
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::DBAFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

Base class for retrieving lists of DBAs to retrieve metadata from

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
