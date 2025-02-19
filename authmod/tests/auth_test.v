import authmod

fn test_that_it_rejects_an_empty_string() {
	a := authmod.parse_www_authenticate('') or {
		assert err.msg() == 'no scheme defined'
		return
	}
	assert false
}

fn test_accepts_just_scheme_with_no_parameters() ! {
	a := authmod.parse_www_authenticate('Bearer')!
	assert a.scheme == 'Bearer'
	assert a.param.len == 0
}

fn test_the_happy_case() ! {
	a := authmod.parse_www_authenticate('Bearer foo="abc",bar="xyz"')!
	assert a.scheme == 'Bearer'
	assert a.param['foo'] == 'abc'
	assert a.param['bar'] == 'xyz'
}

fn test_that_it_ignores_whitespace() ! {
	a := authmod.parse_www_authenticate('Bearer    foo="abc" ,   bar="xyz" ')!
	assert a.scheme == 'Bearer'
	assert a.param['foo'] == 'abc'
	assert a.param['bar'] == 'xyz'
}

fn test_fail1() ! {
	authmod.parse_www_authenticate('Bearer foo') or {
		assert err.msg() == 'parse error'
		return
	}
	assert false
}

fn test_fail2() {
	authmod.parse_www_authenticate('Bearer foo=') or {
		assert err.msg() == 'parse error'
		return
	}
	assert false
}

fn test_fail3() {
	authmod.parse_www_authenticate('Bearer foo=bar') or {
		assert err.msg() == 'parse error'
		return
	}
	assert false
}

fn test_fail4() {
	authmod.parse_www_authenticate('Bearer foo="bar') or {
		assert err.msg() == 'parse error'
		return
	}
	assert false
}

fn test_fail5() {
	authmod.parse_www_authenticate('Bearer foo=bar"') or {
		assert err.msg() == 'parse error'
		return
	}
	assert false
}
