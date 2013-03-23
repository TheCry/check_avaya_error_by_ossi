#!/usr/bin/perl

package LSPServer;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw(@LSP_ACTIVE_SERVER);

# Example @LSP_ACTIVE_SERVER = ('LSP_HOST_1', 'LSP_HOST_2')
our @LSP_ACTIVE_SERVER = ();

1;