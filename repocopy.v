import flag
import os
import regmod { Registry, Repository, get_access_token, get_manifest, is_valid_name, is_valid_tag, link_manifest, put_manifest }
import v.vmod

const embedded_vmod = $embed_file('v.mod')

fn argcheck(name string, value string) {
	if value == '' {
		eprintln('Error: --${name} or -${name[0..1]} not specified')
		eprintln('Use --help for help.')
		exit(1)
	}
}

fn main() {
	vmod_str := embedded_vmod.to_string()
	app := vmod.decode(vmod_str) or { panic(err) }

	mut fp := flag.new_flag_parser(os.args)

	fp.application(app.name)
	fp.version(app.version)
	fp.description(app.description)

	registry := fp.string('registry', `r`, '', 'registry, as myregistry.io or localhost:5000')
	username := fp.string('username', `u`, '', 'username')
	password := fp.string('password', `p`, '', 'password')
	source := fp.string('source', `s`, '', 'source repository, as path/to/source[:tag]')
	target := fp.string('target', `t`, '', 'target repository, as path/to/target[:tag]')
	insecure := fp.bool('insecure', ` `, false, 'insecure access over HTTP')
	verbose := fp.bool('verbose', `v`, false, 'verbose output')
	check := fp.bool('check', `c`, false, 'check, exit code 0 if repositories are identical')

	fp.finalize() or {
		eprintln(err)
		eprintln('Use --help to see available options')
		exit(1)
	}

	argcheck('registry', registry)
	argcheck('username', username)
	argcheck('password', password)
	argcheck('source', source)
	argcheck('target', target)

	protocol := if insecure { 'http' } else { 'https' }

	hostname, port := registry.split_once(':') or {
		port := if insecure { '80' } else { '443' }
		registry, port
	}

	the_registry := Registry{
		hostname: hostname
		protocol: protocol
		port:     port.int()
		username: username
		password: password
	}

	source_name, source_tag := source.split_once(':') or { source, 'latest' }
	target_name, target_tag := target.split_once(':') or { target, 'latest' }

	if !is_valid_name(source_name) {
		eprintln('error: source repository name invalid: ${source_name}')
		exit(1)
	}

	if !is_valid_name(target_name) {
		eprintln('error: target repository name invalid: ${target_name}')
		exit(1)
	}

	if !is_valid_tag(source_tag) {
		eprintln('error: source repository tag invalid: ${source_tag}')
		exit(1)
	}

	if !is_valid_tag(target_tag) {
		eprintln('error: target repository tag invalid: ${target_tag}')
		exit(1)
	}

	source_repo := Repository{
		name: source_name
		tag:  source_tag
	}

	target_repo := Repository{
		name: target_name
		tag:  target_tag
	}

	mut access_token := get_access_token(the_registry, source_repo, target_repo)!
	if verbose {
		eprintln('✓ fetched access token')
	}

	manifest := get_manifest(the_registry, access_token, source_repo)!
	if verbose {
		eprintln('✓ fetched source manifest')
	}

	mut exit_code := 0

	if check {
		target_manifest := get_manifest(the_registry, access_token, target_repo)!
		if verbose {
			eprintln('✓ fetched target manifest')
		}
		if manifest != target_manifest {
			if verbose {
				eprintln('X target and source manifests are not identical')
			}
			exit_code = 1
		} else {
			if verbose {
				eprintln('✓ source and target manifest are identical')
			}
		}
	} else {
		link_manifest(the_registry, access_token, manifest, source_repo, target_repo)!
		if verbose {
			eprintln('✓ linked target from source')
		}

		put_manifest(the_registry, access_token, manifest, target_repo)!
		if verbose {
			eprintln('✓ put target manifest')
		}
	}

	exit(exit_code)
}
