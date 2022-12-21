# Database 2 Class - Assignment 1
## Objective

    Execute a simple REDO algoritm, based on some predefined data.

## Dependencies
###  Json with the following format, to populate the table that will be avalued 

    {
        "table_name": {
                "column_1": [100,300],
                "column_2": [200,400]
            }
    }
>*available in* [*values*](./values.json)

### Text file with a simple log, just as the following example

    <start T1>
    <T1,1,A,20,2000>
    <start T2>
    <T2,1,B,55,1000>
    <commit T2>
    <start T3>
    <T2,2,B,30,1000>
    <commit T1>
    <start T4>
    <T4,1,A,2000,3000>
    <start T5>
    <CKPT (T3,T4,T5)>
    <T4,2,B,1000,8000>
    <start T6>
    <T5,2,A,20,1000>
    <T6,2,A,20,5555>
    <T6,1,B,1000,6666>
    <T4,1,B,1000,2222>
    <commit T4>
    <T2,2,B,1000,8000>
    <commit T6>
    <crash>
>*available in* [*log*](./log.text)

### Limitations

    The number of columns and column's name are both fixed.

### Future steps

    The next step for this assignment will be to make the fixed parameters dinamic.