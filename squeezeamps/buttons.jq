[
	# 4: REW normally, power on long-press
	{"gpio":4,"type":"BUTTON_LOW","pull":true,
		"normal":{"pressed":"ACTRLS_REW","released":"ACTRLS_NONE"},
		"longpress":{"pressed","ACTRLS_POWER",""released":"ACTRLS_NONE"}
	},
	# 32: FF normal, long-press to go 'back'
	{"gpio":21,"type":"BUTTON_LOW","pull":true,
		"normal":{"pressed":"ACTRLS_FWD","released":"ACTRLS_NONE"}
		"longpress":{"pressed":"BCTRLS_LEFT","released":"ACTRLS_NONE"}
	}
]
