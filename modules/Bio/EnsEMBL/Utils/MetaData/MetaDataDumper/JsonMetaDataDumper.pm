
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

package Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::JsonMetaDataDumper;
use base qw( Bio::EnsEMBL::Utils::MetaData::MetaDataDumper );
use Carp;
use JSON;
use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

sub new {
    my ( $proto, @args ) = @_;
    my $self = $proto->SUPER::new(@args);
    my ($file) = rearrange( ['FILE'], @args );
    $self->{file} = $file || 'metadata.json';
    return $self;
}

sub file {
    my ($self) = @_;
    return $self->{file};
}

sub dump_metadata {
    my ( $self, $metadata ) = @_;
    open( my $json_file, '>', $self->file() )
      || croak "Could not write to " . $self->file();
    print $json_file to_json( $metadata, { pretty => 1 } );
    close $json_file;
    return;
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::JsonMetaDataDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation to dump metadata details to a JSON file

=head1 SUBROUTINES/METHODS

=head2 new

=head2 dump_metadata
Description : Dump metadata to the file supplied by the constructor 
Argument : Hash of details

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
