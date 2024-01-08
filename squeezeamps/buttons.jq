[
	# 4: REW normally, power on long-press
	{"gpio":4,"type":"BUTTON_LOW","pull":true,
		"normal":{"pressed":"ACTRLS_VOLUP","released":"ACTRLS_NONE"}
	},
	# 32: FF normal, long-press to go 'back'
	{"gpio":21,"type":"BUTTON_LOW","pull":true,
		"normal":{"pressed":"ACTRLS_VOLDOWN","released":"ACTRLS_NONE"}
	}
]
