module regmod

import json
import net.http
import encoding.base64
import regex
import authmod

pub struct AccessToken {
	access_token string @[required]
}

pub struct Registry {
pub mut:
	hostname string
	protocol string = 'https'
	port     int    = 443
	username string
	password string
}

pub struct Repository {
pub mut:
	name string
	tag  string
}

struct Blob {
pub mut:
	media_type string @[json: mediaType]
	size       int
	digest     string
}

struct Manifest {
pub mut:
	schema_version int    @[json: schemaVersion]
	media_type     string @[json: mediaType]
	config         Blob
	layers         []Blob
}

pub fn get_access_token(registry Registry, source Repository, target Repository) !string {
	root_endpoint := '${registry.protocol}://${registry.hostname}:${registry.port}/v2/'
	mut req := http.get(root_endpoint)!
	www_authenticate := req.header.get(.www_authenticate)!
	auth := authmod.parse_www_authenticate(www_authenticate)!
	// XXX(hholst): Why do we need both push and pull on both repositories?
	auth_endpoint := '${auth.param['realm']}?service=${auth.param['service']}&scope=repository:${source.name}:pull,push&scope=repository:${target.name}:pull,push'
	credentials := base64.encode('${registry.username}:${registry.password}'.bytes())
	req = http.fetch(
		url:    auth_endpoint
		method: .get
		header: http.new_header(http.HeaderConfig{.authorization, 'Basic ${credentials}'})
	)!
	if req.status_code != 200 {
		return error('Invalid credentials: ${req.status_code}')
	}
	access_token := json.decode(AccessToken, req.body)!
	return access_token.access_token
}

pub fn get_manifest(registry Registry, access_token string, repository Repository) !Manifest {
	// curl -H "Authorization: Bearer <token>" "https://myregistry.com/v2/new-repo/manifests/latest"
	endpoint := '${registry.protocol}://${registry.hostname}:${registry.port}/v2/${repository.name}/manifests/${repository.tag}'
	authorization := 'Bearer ${access_token}'
	req := http.fetch(
		url:    endpoint
		method: .get
		header: http.new_header(http.HeaderConfig{.authorization, authorization}, http.HeaderConfig{.accept, 'application/vnd.docker.distribution.manifest.v2+json'})
	)!
	if req.status_code != 200 {
		return error('Failed to get manifest for ${endpoint}: ${req.status_code}')
	}
	manifest := json.decode(Manifest, req.body)!
	return manifest
}

fn link_blob(registry Registry, access_token string, blob Blob, source Repository, target Repository) ! {
	endpoint := '${registry.protocol}://${registry.hostname}:${registry.port}/v2/${target.name}/blobs/uploads/?mount=${blob.digest}&from=${source.name}'
	authorization := 'Bearer ${access_token}'
	req := http.fetch(
		url:    endpoint
		method: .post
		header: http.new_header(http.HeaderConfig{.authorization, authorization}, http.HeaderConfig{.content_type, 'application/vnd.docker.distribution.manifest.v2+json'})
	)!
	if req.status_code != 201 {
		return error('Failed to mount blob on ${target.name} with digest ${blob.digest} from ${source.name}: status code ${req.status_code}')
	}
}

pub fn link_manifest(registry Registry, access_token string, manifest Manifest, source Repository, target Repository) ! {
	mut threads := []thread !{}
	threads << spawn link_blob(registry, access_token, manifest.config, source, target)
	for layer in manifest.layers {
		threads << spawn link_blob(registry, access_token, layer, source, target)
	}
	for t in threads {
		t.wait()!
	}
}

pub fn put_manifest(registry Registry, access_token string, manifest Manifest, repository Repository) ! {
	endpoint := '${registry.protocol}://${registry.hostname}:${registry.port}/v2/${repository.name}/manifests/${repository.tag}'
	data := json.encode(manifest)
	authorization := 'Bearer ${access_token}'
	content_type := 'application/vnd.docker.distribution.manifest.v2+json'
	req := http.fetch(
		url:    endpoint
		method: .put
		header: http.new_header(http.HeaderConfig{.authorization, authorization}, http.HeaderConfig{.content_type, content_type})
		data:   data
	)!
	if req.status_code != 201 {
		return error('Failed to put manifest for ${endpoint}: ${req.status_code}')
	}
}

pub fn is_valid_name(name string) bool {
	valid_name := regex.regex_opt(r'^(?:[a-z0-9]+(?:[_.-][a-z0-9]+)*)(?:/[a-z0-9]+(?:[_.-][a-z0-9]+)*)*$') or {
		panic(err)
	}
	return valid_name.matches_string(name)
}

pub fn is_valid_tag(tag string) bool {
	valid_tag := regex.regex_opt(r'^(?!.*(\.\.|--))[a-zA-Z0-9](?:[a-zA-Z0-9_.-]{0,126}[a-zA-Z0-9])?$') or {
		panic(err)
	}
	return valid_tag.matches_string(tag)
}
