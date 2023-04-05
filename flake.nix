{
  description = "PW's Neovim (pwnvim) Configuration";
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://zmre.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "zmre.cachix.org-1:WIE1U2a16UyaUVr+Wind0JM6pEXBe43PQezdPKoDWLE="
    ];
  };
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
    clipboard-image.url = "github:ekickx/clipboard-image.nvim";
    clipboard-image.flake = false;
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (self: super: {
            vimPlugins =
              super.vimPlugins
              // {
                clipboard-image = super.vimUtils.buildVimPluginFrom2Nix {
                  name = "clipboard-image.nvim";
                  pname = "clipboard-image.nvim";
                  src = inputs.clipboard-image;
                  # buildInputs = [ super.curl ];
                };
              };
          })
        ];
      };

      recursiveMerge = attrList: let
        f = attrPath:
          builtins.zipAttrsWith (n: values:
            if pkgs.lib.tail values == []
            then pkgs.lib.head values
            else if pkgs.lib.all pkgs.lib.isList values
            then pkgs.lib.unique (pkgs.lib.concatLists values)
            else if pkgs.lib.all pkgs.lib.isAttrs values
            then f (attrPath ++ [n]) values
            else pkgs.lib.last values);
      in
        f [] attrList;
    in rec {
      dependencies = with pkgs;
        [
          fd
          ripgrep
          fzy
          zoxide
          bat # previewer for telescope for now
          zk # lsp for markdown notes
          zsh # terminal requires it
          git
          curl # needed to fetch titles from urls
          # todo: research https://github.com/artempyanykh/marksman
          vale # linter for prose
          proselint # ditto
          luaformatter # ditto for lua
          prisma-engines # ditto for schema.prisma files
          #rnix-lsp # nix lsp -- appears to be abandoned?
          nil # nix lsp -- better than rnix?
          #nixfmt # nix formatter used with null-ls
          alejandra # nix formatter alternative
          statix # linter for nix
          shellcheck
          # luajitPackages.lua-lsp
          lua-language-server
          nodePackages.eslint_d # js/ts code formatter and linter
          nodePackages.prettier # ditto
          nodePackages.vscode-langservers-extracted # lsp servers for json, html, css
          nodePackages.svelte-language-server
          nodePackages.diagnostic-languageserver
          nodePackages.typescript-language-server
          nodePackages.bash-language-server
          nodePackages."@tailwindcss/language-server"
          python310Packages.python-lsp-server # todo: is specifying 310 an issue?
          rust-analyzer # lsp for rust
          # rust-analyzer is currently in a partially broken state as it cannot find rust sources so can't
          # help with native language things, which sucks. Here are some issues to track:
          # https://github.com/rust-lang/rust/issues/95736
          # https://github.com/rust-lang/rust-analyzer/issues/13393
          # https://github.com/mozilla/nixpkgs-mozilla/issues/238
          # https://github.com/rust-lang/cargo/issues/10096
          rustfmt
          cargo # have this as a fallback when a local flake isn't in place
          rustc # have this as a fallback when a local flake isn't in place
          # TODO: add back the following when https://github.com/NixOS/nixpkgs/issues/202507 hits
          #llvm # for debugging rust
          #lldb # for debugging rust
          #vscode-extensions.vadimcn.vscode-lldb # for debugging rust
          metals # lsp for scala
        ]
        ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
          ueberzug
          xclip # needed by vim clipboard-image plugin
          wl-clipboard # needed by vim clipboard-image plugin
        ]
        ++ pkgs.lib.optionals pkgs.stdenv.isDarwin
        [pngpaste]; # needed by vim clipboard-image plugin
      neovim-augmented = recursiveMerge [
        pkgs.neovim-unwrapped
        {buildInputs = dependencies;}
      ];
      packages.pwnvim = pkgs.wrapNeovim neovim-augmented {
        viAlias = true;
        vimAlias = true;
        withNodeJs = false;
        withPython3 = false;
        withRuby = false;
        extraPython3Packages = false;
        extraMakeWrapperArgs = ''--prefix PATH : "${pkgs.lib.makeBinPath dependencies}"'';
        # make sure impatient is loaded before everything else to speed things up
        configure = {
          customRC =
            ''
              lua << EOF
                package.path = "${self}/?.lua;" .. package.path
                rustsrc_path = "${pkgs.rustPlatform.rustLibSrc}/core/Cargo.toml"
                vim.env.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}"
                vim.env.RA_LOG = "info,salsa::derived::slot=warn,chalk_recursive=warn,hir_ty::traits=warn,flycheck=trace,rust_analyzer::main_loop=warn,ide_db::apply_change=warn,project_model=debug,proc_macro_api=debug,hir_expand::db=error,ide_assists=debug,ide=debug"
                rustanalyzer_path = "${pkgs.rust-analyzer}/bin/rust-analyzer"
            ''
            + pkgs.lib.readFile ./init.lua
            + ''
              EOF
            '';
          packages.myPlugins = with pkgs.vimPlugins; {
            start = with pkgs.vimPlugins;
              [
                # Common dependencies of other plugins
                popup-nvim # dependency of some other plugins
                plenary-nvim # Library for lua plugins; used by many plugins here

                # Syntax / Language Support ##########################
                # Removing 2022-11-30 as it is slow and treesitter generally does the same thing
                # vim-polyglot # lazy load all the syntax plugins for all the languages
                rust-tools-nvim # lsp stuff and more for rust
                crates-nvim # inline intelligence for Cargo.toml
                nvim-lspconfig # setup LSP for intelligent coding
                null-ls-nvim # formatting and linting via lsp system
                trouble-nvim # navigate all warnings and errors in quickfix-like window
                #nvim-dap # debugging functionality used by rust-tools-nvim
                #nvim-dap-ui # ui for debugging
                lspsaga-nvim
                lsp-format-nvim
                todo-comments-nvim
                fidget-nvim # show lsp status in bottom right but not status line
                neodev-nvim # help for neovim lua api
                nvim-nu # support for nushell scripts
                SchemaStore-nvim # json schemas

                # UI #################################################
                onedarkpro-nvim # colorscheme
                ir_black # colorscheme for basic terminals
                #zephyr-nvim # alternate colorscheme
                telescope-nvim # da best popup fuzzy finder
                telescope-fzy-native-nvim # with fzy gives better results
                telescope-frecency-nvim # and frecency comes in handy too
                #dressing-nvim # dresses up vim.ui.input and vim.ui.select and uses telescope
                nvim-colorizer-lua # color over CSS like #00ff00
                nvim-web-devicons # makes things pretty; used by many plugins below
                nvim-tree-lua # file navigator
                gitsigns-nvim # git status in gutter
                symbols-outline-nvim # navigate the current file better
                lualine-nvim # nice status bar at bottom
                vim-bbye # fix bdelete buffer stuff needed with bufferline
                bufferline-nvim
                indent-blankline-nvim # visual indent
                toggleterm-nvim # better terminal management
                #nvim-treesitter.withAllGrammars # better code coloring (not sure withAllGrammars works anymore)
                (nvim-treesitter.withPlugins (_: pkgs.tree-sitter.allGrammars)) # better code coloring
                playground # treesitter playground
                nvim-treesitter-textobjects # jump around and select based on syntax (class, function, etc.)
                nvim-treesitter-context # keep current block header (func defn or whatever) on first line
                lf-vim

                # Editor Features ####################################
                vim-abolish # better abbreviations / spelling fixer
                nvim-surround # .... updated lua-based alternative to tpope's surround
                vim-unimpaired # bunch of convenient navigation key mappings
                vim-repeat # supports all of the above so you can use .
                vim-rsi # brings keyline bindings to editing (like ctrl-e for end of line when in insert mode)
                vim-visualstar # press * or # on a word to find it
                comment-nvim # code commenter
                #nvim-ts-context-commentstring # makes kommentary contextual for embedded languages
                vim-eunuch # brings cp/mv type commands. :Rename and :Move are particularly handy
                vim-speeddating # allows ctrl-x and ctrl-a to increment/decrement dates

                # Database interactions
                vim-dadbod
                vim-dadbod-ui
                vim-dadbod-completion

                # Autocompletion
                nvim-cmp # generic autocompleter
                cmp-nvim-lsp # use lsp as source for completions
                cmp-nvim-lua # makes vim config editing better with completions
                cmp-buffer # any text in open buffers
                cmp-path # complete paths
                cmp-cmdline # completing in :commands
                cmp-emoji # complete :emojis:
                cmp-nvim-lsp-signature-help # help complete function call by showing args
                cmp-npm # complete node packages in package.json
                nvim-autopairs # balances parens as you type
                nvim-ts-autotag # balance or rename html
                vim-emoji # TODO: redundant now?
                luasnip # snippets driver
                cmp_luasnip # snippets completion
                friendly-snippets # actual library of snippets used by luasnip

                # writing
                zk-nvim # lsp for a folder of notes for searching/linking/etc.
                true-zen-nvim # distraction free, width constrained writing mode
                # twilight-nvim # dim text outside of current scope

                # Misc
                vim-fugitive # git management
                diffview-nvim
                project-nvim
                vim-tmux-navigator # navigate vim and tmux panes together
                impatient-nvim # speeds startup times by caching lua bytecode
                which-key-nvim
                #vim-startuptime
              ]
              ++ pkgs.lib.optionals (!pkgs.stdenv.isDarwin) [
                telescope-media-files-nvim # only works on linux, requires ueberzug, but gives image preview
              ];
            opt = with pkgs.vimPlugins; [
              # grammar check
              vim-grammarous
              # see note about hologram in markdown.lua file. commented out 2023-01-19
              #hologram-nvim # images inline for markdown (only in terminal)
              direnv-vim # auto-execute nix direnv setups -- currently my slowest plugin; enabled by programming filetype
              clipboard-image # only loaded in markdown files
            ];
          };
        };
      };
      apps.pwnvim = flake-utils.lib.mkApp {
        drv = packages.pwnvim;
        name = "pwnvim";
        exePath = "/bin/nvim";
      };
      packages.default = packages.pwnvim;
      apps.default = apps.pwnvim;
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [packages.pwnvim] ++ dependencies;
      };
    });
}
