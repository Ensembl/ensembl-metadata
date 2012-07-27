
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

package Bio::EnsEMBL::Utils::MetaData::MetaDataProcessor;
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;
use strict;
use warnings;

sub new {
    my ($caller,@args) = @_;
    my $class  = ref($caller) || $caller;
    my $self   = bless( {}, $class );
    ($self->{contigs}) = rearrange(['CONTIGS'],@args);
    return $self;
}

sub process_metadata {
    my ( $self, $dbas ) = @_;
    my $metadata;    # arrayref
    for my $dba ( grep {$_->dbc()->dbname() !~ /ancestral/} @{$dbas} ) {

        eval {
        # get metadata container
        my $meta = $dba->get_MetaContainer();
        my $md = {
                species     => $dba->species(),
                species_id  => $dba->species_id(),
                name        => $meta->get_scientific_name() || '',
                taxonomy_id => $meta->get_taxonomy_id() || '',
                assembly_id => $meta->single_value_by_key('assembly.accession') || '',
                assembly_name => $meta->single_value_by_key('assembly.name') || '',
                genebuild => $meta->single_value_by_key('genebuild.start_date') || '',
                division => $meta->get_division() || '',
                dbname        => $dba->dbc()->dbname() };

        # get list of seqlevel contigs
        if(defined $self->{contigs}) {
        my $slice_adaptor = $dba->get_SliceAdaptor();
        for my $contig ( @{ $slice_adaptor->fetch_all("contig") } ) {
            push @{ $md->{accession} }, $contig->seq_region_name();
        }
        }

        push @{ $metadata->{genome} }, $md;
        };
        if($@) {
            warning "Could not get metadata for species ".  $dba->species().":".$@;
        }
    }
    
    $metadata->{genome} = [sort {
            $a->{division} cmp $b->{division} or $a->{name} cmp $b->{name}
        } @{$metadata->{genome}}];
    return $metadata;
} ## end sub process_metadata

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::MetaDataProcessor

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new

=head2 process_metadata
Description : Return hashed metadata for the supplied databases
Argument: Arrayref of DBAdaptor objects

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
