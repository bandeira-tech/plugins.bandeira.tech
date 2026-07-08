# Build a B3nd endpoint integration into an existing system

To trigger a b3nd flow from an existing system to start migration or integration
of any kind between a b3nd service and a non-b3nd system, you call a b3nd node
as such:

```
function existingOperation(data:MyData):void {
    // ... existing operation ...

    myPin.receive(mapMyEntityToOutput(resultData));
}

function mapMyEntityToOutput(data:MyResultData): b3nd.Output[] {
    return [
        ["myuri1", ...],
        ["myuri2", ...]
    ]
}
```
