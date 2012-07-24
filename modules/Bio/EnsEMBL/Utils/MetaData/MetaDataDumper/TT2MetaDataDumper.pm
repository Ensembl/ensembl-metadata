
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

package Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::TT2MetaDataDumper;
use base qw( Bio::EnsEMBL::Utils::MetaData::MetaDataDumper );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Carp;
use XML::Simple;
use strict;
use warnings;

sub new {
    my ( $proto, @args ) = @_;
    my $self = $proto->SUPER::new(@args);
    my ($file) = rearrange( ['FILE'], @args );
    $self->{file} = $file || 'species.tt2';
    $self->{div_links} = { EnsemblBacteria => "http://bacteria.ensembl.org/",
                           EnsemblFungi    => "http://fungi.ensembl.org/",
                           EnsemblMetazoa  => "http://metazoa.ensembl.org/",
                           EnsemblProtists => "http://protists.ensembl.org/",
                           EnsemblPlants   => "http://plants.ensembl.org/" };

    return $self;
}

sub file {
    my ($self) = @_;
    return $self->{file};
}

sub dump_metadata {
    my ( $self, $metadata ) = @_;
    open( my $tt2_file, '>', $self->{file} )
      || croak "Could not write to " . $self->{file};
    print $tt2_file
"<table><tr><th>Species</th><th>Division</th><th>Taxonomy ID</th><th>Assembly</th><th>Genebuild</th></tr>";
    for my $md (
        @{ $metadata->{genome} } )
    {
        my $div_link = $self->{div_links}->{ $md->{division} };
        if ( !defined $div_link ) {
            croak "No division defined for $md->{name}";
        }
        $div_link .= $md->{name};
        my $line =
            "<tr><td><a href='${div_link}'>"
          . $md->{name}
          . "</a></td><td><a href='"
          . $div_link . "'>"
          . $md->{division}
          . "</a></td><td>"
          . $md->{taxonomy_id}
          . "</td><td>"
          . $md->{assembly_name}
          . "</td><td>"
          . $md->{genebuild}
          . "</td><td></tr>\n";
        print $tt2_file $line;
    } ## end for my $md ( sort { $a->...})
    print $tt2_file "</table></div>";
    close $tt2_file;
    return;
} ## end sub dump_metadata

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::XMLMetaDataDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation to dump metadata details to an XML file

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
