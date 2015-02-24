# Authentic

I was increasingly annoyed with having to unlock my phone, launch Google Authenticator and type
in the code to the web page every time I was prompted with a Two Factor Authentication screen.
I wanted a CLI tool to do the same thing on my Mac. For a long time, I've used
[oathtool](http://www.nongnu.org/oath-toolkit/) combined with a shell script that I'd keep adding
my TFA keys to. That obviously was very insecure and I was wondering if I could use Keychain
since it can be used to store various secure credentials.

So long story short, one evening in Nov 2014, I sat down to code a Ruby based tool to offload key storage
to Keychain and `authentic` was born.

## Installation

Install the tool by running:

```shell
$ gem install authentic
```

(you might need to put a `sudo` in front of that command if your Ruby installation requires it)

## Usage

Once installed, the command should be available on the `PATH` so you can type:

```shell
$ authentic help
```

which should print out something like this:

```shell
$ authentic help
Authentic commands:
  authentic add NAME SECRET_KEY [LABEL]  # Add a new TOTP key
  authentic delete NAME                  # Delete a TOTP key
  authentic generate                     # Generate TOTP codes
  authentic help [COMMAND]               # Describe available commands or one specific command
```

In order to start using the tool, you first need to find your TFA key for the service that you are trying
to add. This could be tricky for some services, but this code is actually what is encoded by the QR code
displayed in most services. So click around (or view source) to try to find your TFA key, remember it will
only be displayed the first time you setup TFA for the service.

Once you have your TFA key in hand, adding it to `authentic` is as simple as:

```shell
$ authentic add MyService hedere
✓ Service MyService added to keychain
```

Now you can simply type:

```shell
$ authentic
```

to generate your codes. If you have a single service registered, the generated code will be automatically
copied to the clipboard (if you don't want that run the command with the `-s` flag, as in `authentic -s`).
If you have more than one service registered, the tool will prompt you to select a key number to copy. At
this point you can enter the key number you want to copy or just press `Enter` to exit the tool without copying
anything.

## Disclaimer

I am not a security expert and haven't had any security experts vet this tool. Use it at your own risk, I won't
take any responsibility for anything that happens to you as a result of using this tool.

If you feel (or even better *know*) that I am doing something wrong, please create an Issue or submit a Pull Request.

## Contributing

1. Fork it ( https://github.com/paracycle/authentic/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
