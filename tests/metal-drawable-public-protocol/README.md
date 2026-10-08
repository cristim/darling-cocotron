CAMetalLayer returns id<CAMetalDrawable>, but its header only forward-declared the protocol. A client importing that header could not access texture or the inherited present method. Reuse the existing public CAMetalDrawable.h definition; no new protocol or runtime behavior is added.

From the repository root, using a configured Darling build:

```sh
flock /tmp/agent-locks/darling-heavy-build.lock python3 tests/metal-drawable-public-protocol/build.py /home/cristi/tmp-opencode/metal-resume/build
flock /tmp/agent-locks/darling-heavy-build.lock python3 tests/metal-drawable-public-protocol/build.py /home/cristi/tmp-opencode/metal-resume/build --candidate
```

The first command uses the donor header and fails1 at drawable.texture, also warning that present is undeclared. The second prepends this checkout's public QuartzCore headers and passes0. The authored client uses only CAMetalLayer.h. This removes a measured compile blocker in published MIT DodgeDanger renderer_metal.m; complete game rendering remains separately unverified.

Provenance: rung2 existing QuartzCore CAMetalDrawable.h and Metal MTLDrawable.h; rung4 authored public-client syntax compilation. This is header wiring, not a new implementation or ABI.
