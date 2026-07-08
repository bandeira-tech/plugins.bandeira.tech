# Build a B3nd entrypoint integration into an existing system

To trigger an existing flow from a b3nd flow to integrate a new user entrypoint
or experience of any kind with an existing non-b3nd system, you can follow one
of the options below:

## Call via integration client
```
function createMyIntegrationB3ndPin() {
    const integration = createIntegration(targetClient(options))
    return {
        receive: (outputs:Output[]) => {
            // ... validate ...
            integration.existingOperation(integrationArgs)
        }
    }
}
```

And then with error handling

## Observe trigger from target

```
function existingWorker() {
    myPin.observe(...).onObservation(() => existingOperation(...))
}
```
