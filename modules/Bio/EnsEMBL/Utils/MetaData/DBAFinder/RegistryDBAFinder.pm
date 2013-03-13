
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

package Bio::EnsEMBL::Utils::MetaData::DBAFinder::RegistryDBAFinder;
use base qw( Bio::EnsEMBL::Utils::MetaData::DBAFinder );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use strict;
use warnings;

sub new {
    my ( $proto, @args ) = @_;
    my $self = $proto->SUPER::new(@args);
    ($self->{regfile}) = rearrange(['REGISTRY'], @args);
    $self->{registry} ||= 'Bio::EnsEMBL::Registry';
    if(!defined $self->{regfile}) {
    	throw "No registry file supplied";
    } 
    $self->{registry}->load_all($self->{regfile}); 
    return $self;
}

sub registry {
    my ($self) = @_;
    return $self->{registry};
}

sub get_dbas {
    my ($self) = @_;
    if ( !defined $self->{dbas} ) {
        $self->{dbas} =
          Bio::EnsEMBL::Registry->get_all_DBAdaptors();
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
