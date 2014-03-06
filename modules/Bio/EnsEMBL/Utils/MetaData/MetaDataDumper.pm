
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

package Bio::EnsEMBL::Utils::MetaData::MetaDataDumper;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Log::Log4perl qw(get_logger);
use Data::Dumper;
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $class = ref($proto) || $proto;
  my $self = bless({}, $class);
  $self->{logger} = get_logger();
    ($self->{file}) =
	rearrange(['FILE'], @args);
  return $self;
}

sub do_dump {
  my ($self, $metadata, $outfile) = @_;
  throw "Unimplemented subroutine do_dump() in " .
	ref($self) . ". Please implement";
}

sub dump_metadata {

  my ($self, $metadata, $file, $division) = @_;

  if (defined $division && $division == 1) {

	my %mds_per_division;
	for my $md (@{$metadata}) {
	  push @{$mds_per_division{$md->division()}}, $md;
	}
	for my $division (keys %mds_per_division) {
	  (my $out_file = $file) =~
		s/(.+)(\.[^.]+)$/$1_$division$2/;
	  $self->logger()->info("Writing $division metadata to $out_file");
	  $self->do_dump($mds_per_division{$division}, $out_file);
	  $self->logger()->info("Completed writing $division to $out_file");
	}

  }
  else {

	$self->logger()->info("Writing all metadata to " . $file);
	$self->do_dump($metadata, $file);
	$self->logger()->info("Completed writing to " . $file);

  }

  return;

} ## end sub dump_metadata

sub logger {
  my ($self) = @_;
  return $self->{logger};
}



sub yesno {
  my ($self, $num) = @_;
  return (defined $num && $num + 0 > 0) ? 'Y' : 'N';
}

sub metadata_to_hash {
	my ($self, $metadata) = @_;
	my $genomes = [];
	for my $md (@{$metadata}) {
		push @$genomes, $md->to_hash(1);
	}
	return {genome=>$genomes};	
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::DetailsDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

Base class for rendering details 

=head1 SUBROUTINES/METHODS

=head2 new

=head2 dump_metadata
Description : Render supplied metadata
Arugment: Hash of metadata provided by MetaDataProcessor

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
