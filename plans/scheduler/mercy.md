# Mercy - SuperMemo Help

# Mercy

From SuperMemo Help

[Jump to navigation](#mw-head) [Jump to search](#searchInput)

## Contents

-   [1 Warning](#Warning)
-   [2 Rescheduling outstanding repetitions](#Rescheduling_outstanding_repetitions)
-   [3 Executing repetitions before holiday](#Executing_repetitions_before_holiday)
-   [4 Executing repetitions before an exam](#Executing_repetitions_before_an_exam)
-   [5 Rescheduling in a tree branch](#Rescheduling_in_a_tree_branch)
-   [6 Short history of Mercy in SuperMemo](#Short_history_of_Mercy_in_SuperMemo)
-   [7 Further reading](#Further_reading)
-   [8 Video](#Video)

**[Toolkit](/wiki/Toolkit_menu "Toolkit menu") : Mercy** can be used for the following purposes:

-   reschedule [outstanding repetitions](/wiki/Glossary:Outstanding_element "Glossary:Outstanding element") to a later time, e.g. after a longer break in learning
-   make repetitions ahead of time, e.g. before a vacation
-   spread repetitions in equal portions, e.g. before an exam

**Mercy** is also available as **[Spread](/wiki/Subset_operations "Subset operations")** in subset operations (e.g. in the browser).

## Warning

**Warning!** Each time you use **Mercy** to unload a backlog of repetitions, you add extra hours of work to mastering the same amount of material! You should use it either rarely or only on [low priority material](/wiki/Glossary:Priority_queue "Glossary:Priority queue"). If you use **Mercy** more than a few times per year, please have a closer look at how much work you put on yourself, and [how well your knowledge stored in SuperMemo is formulated](http://super-memory.com/articles/20rules.htm)! To see the effect of **Mercy** on the [forgetting index](/wiki/Glossary:Forgetting_index "Glossary:Forgetting index") see: [Theoretical aspects of learning](http://super-memory.com/articles/theory.htm#FI_Recovery) (forgetting index recovery figure)

# Rescheduling outstanding repetitions

To quickly reschedule [outstanding repetitions](/wiki/Glossary:Outstanding_element "Glossary:Outstanding element") do the following:

1.  Choose **[Toolkit](/wiki/Toolkit_menu "Toolkit menu") : Mercy** (e.g. by pressing _Shift+Alt+M_)
2.  Choose the maximum acceptable number of repetitions per day and type it in at **Number of elements per day**. Alternatively, choose the period in which all [outstanding repetitions](/wiki/Glossary:Outstanding_element "Glossary:Outstanding element") should be done and type it in at **Rescheduling period**
3.  Choose **Update**, e.g. by pressing _Enter_. This will display the rescheduling parameters: number of [elements](/wiki/Glossary:Element "Glossary:Element") per day, length of the rescheduling period, the date on which last [outstanding repetitions](/wiki/Glossary:Outstanding_element "Glossary:Outstanding element") will be made, etc. (use hints to find out more about particular parameters)
4.  If you are satisfied, choose **OK**. Otherwise type in new parameters or choose **Cancel** to quit the dialog box

![SuperMemo: You can use Mercy to make repetitions before a vacation period, randomize or reschedule outstanding repetitions, etc.](![alt text](image.png))
SuperMemo: You can use Mercy to make repetitions before a vacation period, randomize or reschedule outstanding repetitions, etc.

# Executing repetitions before holiday

To make repetitions before a vacation period, you can shift later repetitions to an earlier period:

1.  Choose **[Toolkit](/wiki/Toolkit_menu "Toolkit menu") : Mercy** (e.g. by pressing _Shift+Alt+M_)
2.  Click the checkbox **Consider future repetitions**
3.  In the **Collecting period** editing field, type in the number of days till the end of your vacation
4.  Press _Enter_ and compare the date to the right of **Collecting period**
5.  In the **Rescheduling period** editing field type in the number of days till the end of your repetition period before the vacation (compare the date to the right of the edit field)
6.  Press _Enter_ and compare the date to the right of **Rescheduling period**
7.  If **Number of elements per day** does not exceed a realistic value (in your own estimation), choose **OK**. Otherwise type in new parameters or choose **Cancel** to quit the dialog box

# Executing repetitions before an exam

If you have a collection to master before a set deadline, you can use **Mercy** to spread repetitions in equal portions. If the material is stored in the pending queue, **Mercy** or **Spread** will introduce it into the learning process. For example, if you want to master _Basic English_ collection from SuperMemo World in one month, you can use **Mercy** to spread all its 3000 items in equal portions of 100 items per day.

# Rescheduling in a tree branch

To reschedule [outstanding repetitions](/wiki/Glossary:Outstanding_element "Glossary:Outstanding element") only in a selected [branch](/wiki/Glossary:Branch "Glossary:Branch") of knowledge do as follows:

1.  Select the [branch](/wiki/Glossary:Branch "Glossary:Branch") in the [**Contents** window](/wiki/Contents "Contents") (e.g. click on _Geography_)
2.  Choose **[View](/wiki/Contents_menu#View "Contents menu") : Branch** to view the [branch](/wiki/Glossary:Branch "Glossary:Branch") in the [browser](/wiki/Browser "Browser")
3.  Choose **[Child](/wiki/Browser_menu#Child "Browser menu") : Outstanding** to view only the [outstanding elements](/wiki/Glossary:Outstanding_element "Glossary:Outstanding element") of the selected [branch](/wiki/Glossary:Branch "Glossary:Branch") in the [browser](/wiki/Browser "Browser")
4.  Choose **[Process browser>](/wiki/Subset_operations "Subset operations") : [Learning](/wiki/Subset_operations#Learning "Subset operations") : Spread** to use the **Mercy** dialog to reschedule [outstanding elements](/wiki/Glossary:Outstanding_element "Glossary:Outstanding element") belonging to the selected [branch](/wiki/Glossary:Branch "Glossary:Branch")
5.  Select appropriate rescheduling parameters and choose **OK** (as [above](#Rescheduling_outstanding_repetitions))

If you are an advanced user and you understand how **Mercy** works, you can choose the [**Criteria**](/wiki/Mercy_criteria "Mercy criteria") button to set you own **Mercy** sorting criteria!

# Short history of Mercy in SuperMemo

In [June 1992](http://super-memory.com/articles/cworld.htm), a journalist of Computer World, Andrzej Horodenski, noticed that for lazy or busy users of SuperMemo, an option called **Mercy** would be extremely useful. It would allow users to reschedule [outstanding repetitions](/wiki/Glossary:Outstanding_element "Glossary:Outstanding element") after a vacation period. One month later, SuperMemo World released a new version of SuperMemo 6 for DOS that included the suggested option.

The first **Mercy** algorithm was based on a solid theoretical ground. The item sorting criterion was to minimize the drop in [retention](/wiki/Glossary:Retention "Glossary:Retention") as a result of using **Mercy**. However, the choice of the sorting criterion was not very fortunate. It is easy to notice that an increase in [intervals](/wiki/Glossary:Interval "Glossary:Interval") of short-interval [items](/wiki/Glossary:Item "Glossary:Item") is more detrimental to [retention](/wiki/Glossary:Retention "Glossary:Retention") than the same increase for long-interval items. Consequently, users abusing **Mercy** would pile up lots of hard-to-remember [items](/wiki/Glossary:Item "Glossary:Item") that would recur again and again contributing to overall discouragement of the overwhelmed mind. It is difficult to estimate how many people got hooked on **Mercy** and dropped from among the users of SuperMemo.

A second option was then added to SuperMemo 6. It was called **Wipe** and it was supposed to remove from the learning process all short-[interval](/wiki/Glossary:Interval "Glossary:Interval") [items](/wiki/Glossary:Item "Glossary:Item") with a high degree of [difficulty](/wiki/Glossary:Difficulty "Glossary:Difficulty") (expressed then by [E-Factors](/wiki/Glossary:E-Factor "Glossary:E-Factor")). However, **Wipe** might have done more damage to SuperMemo than ill-conceived **Mercy**. Users would often pile up [items](/wiki/Glossary:Item "Glossary:Item") with **Mercy** and then get them out of the learning process with **Wipe**. Soon they could see that no real progress in learning was taking place. As a result, they would drop out again with detriment to overall popularity of SuperMemo.

In 1994, a new **Mercy** algorithm was designed. The new sorting criterion: minimize the damage to the long-term learning process. The algorithm appeared extremely intricate but has changed **Mercy** beyond recognition. Indeed, it could be seen very soon that the option **Wipe** became entirely superfluous. New **Mercy** would be as abused by the users as the old one, but it would result in less damage and less discouragement. **Mercy** survived and was not removed from subsequent versions of SuperMemo. Users would have a choice to use a tool that could potentially hurt their learning process.

It became clear only much later that the second **Mercy** implementation had a hidden snag. If abused frequently, it was able to repeatedly lengthen the first [interval](/wiki/Glossary:Interval "Glossary:Interval") of newly memorized [items](/wiki/Glossary:Item "Glossary:Item") (after all, they are supposed to be less important for the long-term learning process). This problem was compounded by the fact that all older SuperMemo algorithms (1989-1996) were highly sensitive to delaying repetitions, esp. at the early stages of learning. Consequently, [items](/wiki/Glossary:Item "Glossary:Item") that were dramatically postponed with **Mercy** and scored well in repetitions would have reached disproportionately long [intervals](/wiki/Glossary:Interval "Glossary:Interval").

These problems have been partly solved in December 1996 by implementing the following features in SuperMemo:

1.  removing sensitivity to repetition delay of [Algorithm SM-8](http://super-memory.com/english/algsm8.htm) by indexing optimization matrices with repetition categories rather than repetition numbers (for example, an [item](/wiki/Glossary:Item "Glossary:Item") repeated twice would be treated as repeated 2.4 times if its [interval](/wiki/Glossary:Interval "Glossary:Interval") was artificially lengthened)
2.  implementing new multi-criterial heuristic **Mercy** algorithm that combines its earlier emphasis on minimizing the damage to the long-term learning process with adding extra attention to [items](/wiki/Glossary:Item "Glossary:Item") that have recently been introduced into the [collection](/wiki/Glossary:Collection "Glossary:Collection")

In December 1997, **Mercy** has been enhanced with the option [**Criteria**](/wiki/Mercy_criteria "Mercy criteria"). This option makes it possible for the user to choose his or her own **Mercy** criteria. This was to be the end of the 5-year-long process of coming to understand of what really people expect from **Mercy**. The following sorting criteria can be balanced by the user:

-   [item](/wiki/Glossary:Item "Glossary:Item")'s [priority](/wiki/Glossary:Priority "Glossary:Priority"),
-   repetition lateness,
-   investment (in the item),
-   easiness (of the item) and
-   recency of introducing the item into the learning process.

SuperMemo 99 added a possibility of random rescheduling and rescheduling that preserves the original order of repetitions. All in all, random rescheduling is a very powerful and useful option. These are two main reasons for using random **Mercy**:

1.  There is no predictable pattern in repetitions (e.g. from short [intervals](/wiki/Glossary:Interval "Glossary:Interval") to long intervals, from easy material to difficult material, etc.). This makes repetitions vary in difficulty and makes the learning process more representative and enjoyable
2.  There are no cumulative trends in rescheduling. For example, constant rescheduling with the easy-items-first criterion may indefinitely postpone difficult [items](/wiki/Glossary:Item "Glossary:Item")! With random rescheduling, [intervals](/wiki/Glossary:Interval "Glossary:Interval") on average will also grow indefinitely; however, there will be no cumulative pattern and the user will sooner or later notice dramatic deterioration in the quality of recall which, hopefully, should make him or her reconsider the abuse of **Mercy**

SuperMemo 2000 added a powerful rescheduling tool that can be [branch](/wiki/Glossary:Branch "Glossary:Branch")/[subset](/wiki/Glossary:Subset "Glossary:Subset")\-specific: **[Postpone](/wiki/Postpone "Postpone")**. In SuperMemo 2002, **Postpone** became even more content and priority sensitive. This gradually reduced the need for using **Mercy**. In [incremental reading](/wiki/Glossary:Incremental_reading "Glossary:Incremental reading"), **Postpone** is the tool of choice for resolving material overload. **Mercy** would only be used occasionally, e.g. to spread the load of repetitions, randomize repetitions, advance future repetitions, etc. It no longer played a central role in learning.

Finally, SuperMemo 2006 dealt an ultimate death-blow to **Mercy**. With the [priority queue](/wiki/Glossary:Priority_queue "Glossary:Priority queue"), repetition [auto-sort](/wiki/Glossary:Auto-sort "Glossary:Auto-sort") and [auto-postpone](/wiki/Glossary:Auto-postpone "Glossary:Auto-postpone"), **Mercy** is no longer needed to resolve the overload of [outstanding material](/wiki/Glossary:Outstanding_element "Glossary:Outstanding element"). A substantial overload becomes a norm, and the user is supposed to only do his or her best to pass as much of the top-priority material as possible. It might seem that this could reduce one of the famous "advantages" of SuperMemo, being a ruthless executor of the demand to reduce the [outstanding material](/wiki/Glossary:Outstanding_element "Glossary:Outstanding element") to zero. However, evidence suggests that the elimination of obligatory learning greatly enhances user's enthusiasm for learning. Paradoxically, without a specific demand on the number of daily repetitions, users seem eager to actually spend more time on learning than in the past!

# Further reading

-   [**Mercy** criteria](/wiki/Mercy_criteria "Mercy criteria")
-   [Postpone, Advance and Mercy](/wiki/Postpone,_Advance_and_Mercy "Postpone, Advance and Mercy")
-   [Postpone](/wiki/Postpone "Postpone")
-   [Incremental reading](/wiki/Incremental_reading "Incremental reading")
-   [Priority queue](/wiki/Priority_queue "Priority queue")
-   [FAQ: Repetition overload](http://super-memory.com/help/faq/overload.htm)

# Video

[Mercy vs. Spread](https://youtu.be/tmZV9pRS2_w)

Retrieved from "[http://help.supermemo.org/index.php?title=Mercy&oldid=9864](https://help.supermemo.org/index.php?title=Mercy&oldid=9864)"

## Embedded Content