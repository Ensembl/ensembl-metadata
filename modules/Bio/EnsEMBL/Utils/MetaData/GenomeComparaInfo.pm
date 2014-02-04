
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

package Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo;
use Log::Log4perl qw(get_logger);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $class = ref($proto) || $proto;
  my $self = bless({}, $class);
  $self->{logger} = get_logger();
  ($self->{division}, $self->{method}, $self->{dbname},
   $self->{genomes}
  ) = rearrange(['DIVISION', 'METHOD', 'DBNAME', 'GENOMES'], @args);
  return $self;
}

sub dbID {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{dbID} = $arg;
  }
  return $self->{dbID};
}

sub adaptor {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{adaptor} = $arg;
  }
  return $self->{adaptor};
}

sub dbname {
  my ($self, $arg) = @_;
  $self->{dbname} = $arg if (defined $arg);
  return $self->{dbname};
}

sub method {
  my ($self, $arg) = @_;
  $self->{method} = $arg if (defined $arg);
  return $self->{method};
}

sub division {
  my ($self, $arg) = @_;
  $self->{division} = $arg if (defined $arg);
  return $self->{division};
}

sub genomes {
  my ($self, $arg) = @_;
  $self->{genomes} = $arg if (defined $arg);
  return $self->{genomes};
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo

=head1 SYNOPSIS

=head1 DESCRIPTION

TODO

=head1 SUBROUTINES/METHODS

=head2 new

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut

1;
