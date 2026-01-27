FROM fedora:42

LABEL maintainer="nuno.fonseca at biopolis.pt"

RUN dnf update -y && dnf install -y bzip2-devel  bzip2 zlib-devel git gcc wget conda curl tar bash pip && dnf clean all
ADD src ./src/
ADD tests ./tests/
ADD test-workflow ./test-workflow/
COPY install.sh .
COPY pyproject.toml .
RUN echo '#!/usr/bin/env bash' > /usr/bin/catnip_env
RUN echo 'bash' >> /usr/bin/catnip_env
RUN chmod u+x /usr/bin/catnip_env
RUN chmod a+x install.sh
RUN ./install.sh -i /opt && rm -rf tests pyproject.toml install.sh
ENTRYPOINT ["/usr/bin/catnip_env"]
