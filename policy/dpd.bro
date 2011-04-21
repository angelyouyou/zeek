##! Activates port-independent protocol detection.

@load functions
@load signatures

module DPD;

# Add the DPD signatures.
redef signature_files += "dpd.sig";
redef enum Log::ID += { DPD };

export {
	type Info: record {
		ts:             time            &log;
		id:             conn_id         &log;
		proto:          transport_proto &log;
		analyzer:       string          &log;
		failure_reason: string          &log;
	};
}

redef record connection += {
	dpd: Info &optional;
};

event bro_init()
	{
	Log::create_stream(DPD, [$columns=Info]);
	
	for ( a in dpd_config )
		{
		for ( p in dpd_config[a]$ports )
			{
			if ( p !in dpd_analyzer_ports )
				dpd_analyzer_ports[p] = set();
			add dpd_analyzer_ports[p][a];
			}
		}
	}

event protocol_confirmation(c: connection, atype: count, aid: count) &priority=10
	{
	if ( fmt("-%s",analyzer_name(atype)) in c$service )
		delete c$service[fmt("-%s",analyzer_name(atype))];

	add c$service[analyzer_name(atype)];
	}

event protocol_violation(c: connection, atype: count, aid: count,
				reason: string) &priority=10
	{
	if ( analyzer_name(atype) in c$service )
		delete c$service[analyzer_name(atype)];
	add c$service[fmt("-%s",analyzer_name(atype))];
	
	Log::write(DPD, [$ts=network_time(),
	                 $id=c$id,
	                 $proto=get_conn_transport_proto(c$id),
	                 $analyzer=analyzer_name(atype),
	                 $failure_reason=reason]);
	}

