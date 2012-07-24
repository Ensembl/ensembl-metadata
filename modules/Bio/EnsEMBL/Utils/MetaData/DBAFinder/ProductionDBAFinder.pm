
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

use strict;
use warnings;

package Bio::EnsEMBL::Utils::MetaData::DBAFinder::ProductionDBAFinder;
use base qw( Bio::EnsEMBL::Utils::MetaData::DBAFinder::DbHostDBAFinder );
use Bio::EnsEMBL::Utils::Exception qw/throw warning/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Data::Dumper;

sub new {
    my ( $proto, @args ) = @_;
    my $self = $proto->SUPER::new(@args);
    # get the production database
    my ( $mhost, $mport, $muser, $mpass, $mdbname ) =
      rearrange( [ 'MHOST', 'MPORT', 'MUSER', 'MPASS', 'MDBNAME' ],
                 @args );
    $self->{production_dbc} =
      Bio::EnsEMBL::DBSQL::DBConnection->new( -USER =>,
                                              $muser,
                                              -PASS =>,
                                              $mpass,
                                              -HOST =>,
                                              $mhost,
                                              -PORT =>,
                                              $mport,
                                              -DBNAME =>,
                                              $mdbname );
    return $self;
}

sub get_dbas {
    my ($self) = @_;
    # get parents and hash by DB
    my $dbs;
    for my $dba (@{ $self->SUPER::get_dbas() }) {
        push @{$dbs->{$dba->dbc()->dbname()}},$dba;
    }
    my $dbas = [];
    # get list of dbs
    for my $db (
        @{  $self->{production_dbc}->sql_helper()->execute_simple(
                -SQL =>
q/select full_db_name from db_list join db using (db_id) where db_type='core' and is_current=1/
            ) } )
    {
        my $dba_list=  $dbs->{$db};
        if(defined $dba_list) {
           push @$dbas,@$dba_list; 
        }  else {
            throw "Expected database $db not found";
        }  
    }
    return $dbas;
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
