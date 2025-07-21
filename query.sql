SELECT hostname || '|' || datadir from gp_segment_configuration WHERE role = 'p' ORDER BY hostname, datadir;
