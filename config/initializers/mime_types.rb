# Adobe publishes no media type for its swatch format, so this is the one the
# tools that read it send. Registering it is what lets a palette be asked for
# as `.ase` on the same route that serves it as a page.
Mime::Type.register "application/x-adobe-ase", :ase
