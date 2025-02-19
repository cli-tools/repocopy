module authmod

import strings

pub struct Auth {
pub mut:
	scheme string
	param  map[string]string
}

pub fn (a Auth) to_string() string {
	if a.param.len == 0 {
		return a.scheme
	}
	mut b := strings.new_builder(128)
	b.write_string(a.scheme)
	b.write_byte(` `)
	mut first := true
	for key, val in a.param {
		if first {
			first = false
		} else {
			b.write_byte(`,`)
		}
		b.write_string(key)
		b.write_byte(`=`)
		b.write_byte(`"`)
		b.write_string(val)
		b.write_byte(`"`)
	}
	return b.str()
}

pub fn parse_www_authenticate(s string) !Auth {
	n := s.len
	mut a := Auth{}
	mut i := 0
	for {
		if i == n || s[i] == ` ` {
			a.scheme = s[0..i]
			break
		} else {
			i++
		}
	}
	if a.scheme == '' {
		return error('no scheme defined')
	}
	// parse parameters
	for i < n {
		mut name := ''
		mut value := ''
		// Skip whitespace
		for i < n && s[i] == ` ` {
			i++
		}
		mut j := i
		// parse name
		for {
			if j == n {
				break
			} else if s[j] == `=` {
				name = s[i..j]
				j++
				i = j
				break
			} else {
				j++
			}
		}
		// parse value
		if j == n {
			return error('parse error')
		}
		if s[j] != `"` {
			return error('parse error')
		}
		j++
		i = j
		for {
			if j == n {
				return error('parse error')
			} else if s[j] == `"` {
				value = s[i..j]
				// store value
				a.param[name] = value
				j++
				i = j
				break
			} else {
				j++
			}
		}
		// check if more parameters
		for {
			if i == n {
				break
			} else if s[i] == `,` {
				i++
				break
			} else if s[i] == ` ` {
				i++
			} else {
				return error('parse error')
			}
		}
	}
	return a
}
